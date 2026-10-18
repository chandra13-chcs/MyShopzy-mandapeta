const { createHmac, timingSafeEqual } = require('node:crypto');

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TOKEN_AUDIENCE = 'myshopzy-customer';
const DEVELOPMENT_TOKEN_ISSUER = 'myshopzy-development-auth';
const CUSTOMER_TOKEN_ISSUER = 'myshopzy-customer-auth';
const TOKEN_LIFETIME_SECONDS = 15 * 60;

function encodeJson(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function signCustomerToken(customerUserId, secret, nowSeconds, issuer) {
  const header = encodeJson({ alg: 'HS256', typ: 'JWT' });
  const payload = encodeJson({
    sub: customerUserId,
    iss: issuer,
    aud: TOKEN_AUDIENCE,
    iat: nowSeconds,
    exp: nowSeconds + TOKEN_LIFETIME_SECONDS,
  });
  const unsignedToken = `${header}.${payload}`;
  const signature = createHmac('sha256', secret)
    .update(unsignedToken)
    .digest('base64url');
  return `${unsignedToken}.${signature}`;
}

function verifyCustomerToken(token, secret, nowSeconds, issuer) {
  if (typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  let header;
  let payload;
  let signature;
  try {
    header = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
    payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    signature = Buffer.from(parts[2], 'base64url');
  } catch (_) {
    return null;
  }
  if (
    header?.alg !== 'HS256' ||
    header?.typ !== 'JWT' ||
    !payload ||
    typeof payload !== 'object' ||
    !UUID_PATTERN.test(payload.sub ?? '') ||
    payload.iss !== issuer ||
    payload.aud !== TOKEN_AUDIENCE ||
    !Number.isInteger(payload.iat) ||
    !Number.isInteger(payload.exp) ||
    payload.iat > nowSeconds ||
    payload.exp <= nowSeconds ||
    payload.exp - payload.iat !== TOKEN_LIFETIME_SECONDS
  ) {
    return null;
  }
  const expected = createHmac('sha256', secret)
    .update(`${parts[0]}.${parts[1]}`)
    .digest();
  if (
    signature.length !== expected.length ||
    !timingSafeEqual(signature, expected)
  ) {
    return null;
  }
  return payload;
}

function createCustomerAuthenticator({ databasePool, config, now }) {
  const nowSeconds = now ?? (() => Math.floor(Date.now() / 1000));
  return async (req, res, next) => {
    const authorization = req.get('authorization') ?? '';
    const match = /^Bearer ([A-Za-z0-9._-]+)$/.exec(authorization);
    const token = match?.[1];
    const secret = config.customerSessionSecret;
    let claims =
      typeof secret === 'string' && Buffer.byteLength(secret, 'utf8') >= 32
        ? verifyCustomerToken(
            token,
            secret,
            nowSeconds(),
            CUSTOMER_TOKEN_ISSUER,
          )
        : null;

    if (!claims && config.nodeEnv !== 'production') {
      const developmentSecret = config.developmentCustomerSessionSecret;
      if (
        typeof developmentSecret === 'string' &&
        Buffer.byteLength(developmentSecret, 'utf8') >= 32
      ) {
        claims = verifyCustomerToken(
          token,
          developmentSecret,
          nowSeconds(),
          DEVELOPMENT_TOKEN_ISSUER,
        );
      }
    }
    if (!claims || !databasePool) {
      return res.status(401).json({
        error: {
          code: 'AUTHENTICATION_REQUIRED',
          message: 'Customer authentication is required.',
        },
      });
    }

    try {
      const result = await databasePool.query(
        `SELECT c.user_id
         FROM app.customers AS c
         JOIN app.users AS u ON u.id = c.user_id
         WHERE c.user_id = $1
           AND u.system_role = 'customer'
           AND u.status = 'active'`,
        [claims.sub],
      );
      if (result.rows.length !== 1) {
        return res.status(401).json({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'Customer authentication is required.',
          },
        });
      }
      req.auth = { customerUserId: claims.sub };
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

module.exports = {
  CUSTOMER_TOKEN_ISSUER,
  DEVELOPMENT_TOKEN_ISSUER,
  TOKEN_LIFETIME_SECONDS,
  createCustomerAuthenticator,
  signCustomerToken,
  verifyCustomerToken,
};
