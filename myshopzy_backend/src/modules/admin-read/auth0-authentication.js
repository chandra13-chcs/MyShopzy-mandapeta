const ADMIN_USER_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

let joseModule;

function loadJose() {
  joseModule ??= import('jose');
  return joseModule;
}

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

  let verificationKeySet;

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
      const { createRemoteJWKSet, jwtVerify } = await loadJose();
      verificationKeySet ??= createRemoteJWKSet(
        new URL('.well-known/jwks.json', issuerUrl),
      );
      ({ payload } = await jwtVerify(match[1], verificationKeySet, {
        issuer: issuerUrl,
        audience,
        algorithms: ['RS256'],
        requiredClaims: ['exp', 'sub'],
      }));
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
