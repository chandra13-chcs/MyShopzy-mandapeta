const ADMIN_USER_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const { createAuth0JwtVerifier } = require('../shared/auth0-jwt');

function sendAuthError(res, req, status, code, message) {
  return res.status(status).json({
    error: { code, message },
    meta: { requestId: req.requestId },
  });
}

function createAuth0AdminAuthenticator({
  databasePool,
  issuerUrl,
  audience,
  adminUserIdClaim,
}) {
  if (!databasePool || !issuerUrl || !audience || !adminUserIdClaim) {
    throw new TypeError('Database and complete Auth0 admin configuration are required.');
  }

  const verifyAuth0Jwt = createAuth0JwtVerifier({ issuerUrl, audience });

  return async function authenticateAdmin(req, res, next) {
    const authorization = req.get('authorization') ?? '';
    const match = /^Bearer ([^\s]+)$/i.exec(authorization);
    if (!match || match[1].length > 16384) {
      return sendAuthError(
        res,
        req,
        401,
        'AUTHENTICATION_REQUIRED',
        'Admin authentication is required.',
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
        'Admin authentication could not be verified.',
      );
    }

    if (
      typeof payload.sub !== 'string' ||
      !payload.sub ||
      !ADMIN_USER_ID_PATTERN.test(payload[adminUserIdClaim] ?? '')
    ) {
      return sendAuthError(
        res,
        req,
        403,
        'ADMIN_ACCESS_REQUIRED',
        'An active Super Admin account is required.',
      );
    }

    try {
      const result = await databasePool.query(
        `SELECT id
         FROM app.users
         WHERE id = $1::uuid
           AND system_role = 'admin'
           AND status = 'active'
         LIMIT 2`,
        [payload[adminUserIdClaim]],
      );
      if (
        result.rows.length !== 1 ||
        !ADMIN_USER_ID_PATTERN.test(result.rows[0].id ?? '')
      ) {
        return sendAuthError(
          res,
          req,
          403,
          'ADMIN_ACCESS_REQUIRED',
          'An active Super Admin account is required.',
        );
      }

      req.auth = { adminUserId: result.rows[0].id };
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

module.exports = { createAuth0AdminAuthenticator };
