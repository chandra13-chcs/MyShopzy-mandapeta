const { createHmac, timingSafeEqual } = require('node:crypto');
const express = require('express');

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TOKEN_ISSUER = 'myshopzy-development-auth';
const TOKEN_AUDIENCE = 'myshopzy-customer';
const TOKEN_LIFETIME_SECONDS = 15 * 60;

function sendAuthError(res, status, code, message) {
  return res.status(status).json({ error: { code, message } });
}

function parseVerificationBody(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return null;
  const keys = Object.keys(body);
  if (
    keys.length !== 2 ||
    !keys.includes('phoneNumber') ||
    !keys.includes('otp') ||
    typeof body.phoneNumber !== 'string' ||
    typeof body.otp !== 'string'
  ) {
    return null;
  }

  const phoneNumber = body.phoneNumber.trim();
  const normalizedPhone = phoneNumber.replace(/[\s()-]/g, '');
  if (
    !/^\+?91[6-9]\d{9}$/.test(normalizedPhone) &&
    !/^[6-9]\d{9}$/.test(normalizedPhone)
  ) {
    return null;
  }
  if (!/^\d{6}$/.test(body.otp)) return null;
  const digits = normalizedPhone.replace(/\D/g, '');
  return {
    nationalNumber: digits.length === 12 ? digits.slice(2) : digits,
    otp: body.otp,
  };
}

function isConfigured(config) {
  return (
    typeof config.developmentCustomerOtp === 'string' &&
    /^\d{6}$/.test(config.developmentCustomerOtp) &&
    typeof config.developmentCustomerSessionSecret === 'string' &&
    Buffer.byteLength(config.developmentCustomerSessionSecret, 'utf8') >= 32
  );
}

function encodeJson(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function signToken(customerUserId, secret, nowSeconds) {
  const header = encodeJson({ alg: 'HS256', typ: 'JWT' });
  const payload = encodeJson({
    sub: customerUserId,
    iss: TOKEN_ISSUER,
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

function verifyToken(token, secret, nowSeconds) {
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
    payload.iss !== TOKEN_ISSUER ||
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

function createDevelopmentCustomerAuth({
  databasePool,
  config,
  now = () => Math.floor(Date.now() / 1000),
}) {
  const router = express.Router();
  const isProduction = config.nodeEnv === 'production';

  router.post('/auth/development/verify-otp', async (req, res, next) => {
    if (isProduction) {
      return sendAuthError(res, 404, 'NOT_FOUND', 'API endpoint not found.');
    }
    if (!isConfigured(config)) {
      return sendAuthError(
        res,
        503,
        'DEVELOPMENT_AUTH_UNAVAILABLE',
        'Development customer authentication is not configured.',
      );
    }
    const parsed = parseVerificationBody(req.body);
    if (!parsed) {
      return sendAuthError(
        res,
        400,
        'INVALID_REQUEST',
        'Enter a valid Indian mobile number and six-digit code.',
      );
    }
    const expectedOtp = Buffer.from(config.developmentCustomerOtp);
    const providedOtp = Buffer.from(parsed.otp);
    if (!timingSafeEqual(expectedOtp, providedOtp)) {
      return sendAuthError(
        res,
        401,
        'INVALID_OTP',
        'The development verification code is invalid.',
      );
    }
    if (!databasePool) {
      return sendAuthError(
        res,
        503,
        'DATABASE_UNAVAILABLE',
        'The customer service is temporarily unavailable.',
      );
    }

    try {
      const phoneVariants = [
        parsed.nationalNumber,
        `91${parsed.nationalNumber}`,
      ];
      const result = await databasePool.query(
        `SELECT u.id
         FROM app.users AS u
         JOIN app.customers AS c ON c.user_id = u.id
         WHERE regexp_replace(u.phone, '[^0-9]', '', 'g') = ANY($1::text[])
           AND u.system_role = 'customer'
           AND u.status = 'active'
         LIMIT 2`,
        [phoneVariants],
      );
      if (
        result.rows.length !== 1 ||
        !UUID_PATTERN.test(result.rows[0].id ?? '')
      ) {
        return sendAuthError(
          res,
          401,
          'INVALID_OTP',
          'The development verification code is invalid.',
        );
      }
      const nowSeconds = now();
      return res.status(200).json({
        data: {
          accessToken: signToken(
            result.rows[0].id,
            config.developmentCustomerSessionSecret,
            nowSeconds,
          ),
          tokenType: 'Bearer',
          expiresIn: TOKEN_LIFETIME_SECONDS,
        },
      });
    } catch (error) {
      return next(error);
    }
  });

  const authenticateCustomer = async (req, res, next) => {
    if (
      isProduction ||
      typeof config.developmentCustomerSessionSecret !== 'string' ||
      Buffer.byteLength(config.developmentCustomerSessionSecret, 'utf8') < 32
    ) {
      return sendAuthError(
        res,
        401,
        'AUTHENTICATION_REQUIRED',
        'Customer authentication is required.',
      );
    }
    const authorization = req.get('authorization') ?? '';
    const match = /^Bearer ([A-Za-z0-9_.-]+)$/.exec(authorization);
    const claims = match
      ? verifyToken(match[1], config.developmentCustomerSessionSecret, now())
      : null;
    if (!claims || !databasePool) {
      return sendAuthError(
        res,
        401,
        'AUTHENTICATION_REQUIRED',
        'Customer authentication is required.',
      );
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
        return sendAuthError(
          res,
          401,
          'AUTHENTICATION_REQUIRED',
          'Customer authentication is required.',
        );
      }
      req.auth = { customerUserId: claims.sub };
      return next();
    } catch (error) {
      return next(error);
    }
  };

  return { router, authenticateCustomer };
}

module.exports = {
  createDevelopmentCustomerAuth,
  TOKEN_LIFETIME_SECONDS,
};
