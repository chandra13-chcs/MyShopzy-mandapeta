const { timingSafeEqual } = require('node:crypto');
const express = require('express');
const {
  DEVELOPMENT_TOKEN_ISSUER,
  TOKEN_LIFETIME_SECONDS,
  signCustomerToken,
  verifyCustomerToken,
} = require('./customer-session');

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
          accessToken: signCustomerToken(
            result.rows[0].id,
            config.developmentCustomerSessionSecret,
            nowSeconds,
            DEVELOPMENT_TOKEN_ISSUER,
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
      ? verifyCustomerToken(
          match[1],
          config.developmentCustomerSessionSecret,
          now(),
          DEVELOPMENT_TOKEN_ISSUER,
        )
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
