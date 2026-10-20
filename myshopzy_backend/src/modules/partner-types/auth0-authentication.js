const { getPartnerTypeProfile } = require('./profiles');
const { createAuth0JwtVerifier } = require('../shared/auth0-jwt');

function sendAuthError(res, req, status, code, message) {
  return res.status(status).json({
    error: { code, message },
    meta: { requestId: req.requestId },
  });
}

function createPartnerAuthenticator({
  databasePool,
  issuerUrl,
  audience,
  emailClaim = 'email',
  emailVerifiedClaim = 'email_verified',
}) {
  if (!databasePool || !issuerUrl || !audience) {
    throw new TypeError('Database and complete Auth0 partner configuration are required.');
  }

  const verifyAuth0Jwt = createAuth0JwtVerifier({ issuerUrl, audience });

  return async function authenticatePartner(req, res, next) {
    const authorization = req.get('authorization') ?? '';
    const match = /^Bearer\s+(\S+)$/i.exec(authorization);
    if (!match || match[1].length > 16384) {
      return sendAuthError(
        res,
        req,
        401,
        'AUTHENTICATION_REQUIRED',
        'Partner authentication is required.',
      );
    }

    let payload;
    try {
      payload = await verifyAuth0Jwt(match[1]);
    } catch {
      return sendAuthError(
        res,
        req,
        401,
        'INVALID_AUTHENTICATION',
        'Partner authentication could not be verified.',
      );
    }

    if (
      typeof payload.sub !== 'string' ||
      !payload.sub ||
      typeof payload[emailClaim] !== 'string' ||
      !payload[emailClaim].trim() ||
      payload[emailVerifiedClaim] !== true
    ) {
      return sendAuthError(
        res,
        req,
        403,
        'PARTNER_IDENTITY_REQUIRED',
        'A verified Auth0 email address is required.',
      );
    }

    try {
      const userResult = await databasePool.query(
        `SELECT id
         FROM app.users
         WHERE lower(email) = lower($1)
           AND status = 'active'
         LIMIT 2`,
        [payload[emailClaim].trim()],
      );
      if (userResult.rows.length !== 1) {
        return sendAuthError(
          res,
          req,
          403,
          'PARTNER_USER_NOT_FOUND',
          'No active partner user matches this verified email.',
        );
      }

      const userId = userResult.rows[0].id;
      const membershipResult = await databasePool.query(
        `SELECT
           membership.partner_id,
           membership.role,
           partner.partner_type,
           COALESCE(
             array_agg(DISTINCT shop.id) FILTER (WHERE shop.id IS NOT NULL),
             ARRAY[]::uuid[]
           ) AS shop_ids
         FROM app.partner_memberships AS membership
         JOIN app.partners AS partner ON partner.id = membership.partner_id
         LEFT JOIN app.shops AS shop ON shop.partner_id = partner.id
         WHERE membership.user_id = $1::uuid
           AND membership.status = 'active'
         GROUP BY membership.partner_id, membership.role, partner.partner_type
         ORDER BY membership.partner_id
         LIMIT 2`,
        [userId],
      );
      if (membershipResult.rows.length === 0) {
        return sendAuthError(
          res,
          req,
          403,
          'PARTNER_MEMBERSHIP_REQUIRED',
          'An active partner membership is required.',
        );
      }
      if (membershipResult.rows.length !== 1) {
        return sendAuthError(
          res,
          req,
          403,
          'PARTNER_CONTEXT_AMBIGUOUS',
          'This user has multiple active partner memberships.',
        );
      }

      const membership = membershipResult.rows[0];
      if (!getPartnerTypeProfile(membership.partner_type)) {
        return sendAuthError(
          res,
          req,
          403,
          'PARTNER_TYPE_UNSUPPORTED',
          'This partner type is not supported.',
        );
      }

      req.partnerContext = {
        userId,
        partnerId: membership.partner_id,
        role: membership.role,
        partnerType: membership.partner_type,
        shopIds: membership.shop_ids,
      };
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

module.exports = { createPartnerAuthenticator };
