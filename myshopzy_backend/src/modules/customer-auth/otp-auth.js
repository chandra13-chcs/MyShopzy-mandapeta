const {
  createHmac,
  randomInt,
  randomUUID,
  timingSafeEqual,
} = require('node:crypto');
const express = require('express');
const {
  CUSTOMER_TOKEN_ISSUER,
  TOKEN_LIFETIME_SECONDS,
  signCustomerToken,
} = require('./customer-session');
const { createWhatsAppOtpProvider } = require('./whatsapp-otp-provider');

const OTP_LENGTH = 6;
const OTP_LIFETIME_SECONDS = 5 * 60;
const OTP_MAX_ATTEMPTS = 5;
const RESEND_COOLDOWN_SECONDS = 30;
const PHONE_WINDOW_SECONDS = 15 * 60;
const PHONE_MAX_REQUESTS = 3;
const IP_WINDOW_SECONDS = 60 * 60;
const IP_MAX_REQUESTS = 10;

class AuthFlowError extends Error {
  constructor(status, code, message, retryAfterSeconds = null) {
    super(message);
    this.status = status;
    this.code = code;
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

function normalizePhone(value) {
  if (typeof value !== 'string') return null;
  const normalized = value.trim().replace(/[\s()-]/g, '');
  if (
    !/^\+?91[6-9]\d{9}$/.test(normalized) &&
    !/^[6-9]\d{9}$/.test(normalized)
  ) {
    return null;
  }
  const digits = normalized.replace(/\D/g, '');
  return {
    nationalNumber: digits.length === 12 ? digits.slice(2) : digits,
    e164: `+91${digits.length === 12 ? digits.slice(2) : digits}`,
    whatsappNumber: `91${digits.length === 12 ? digits.slice(2) : digits}`,
    variants: [
      digits.length === 12 ? digits.slice(2) : digits,
      `91${digits.length === 12 ? digits.slice(2) : digits}`,
    ],
  };
}

function parseRequestBody(body, expectedKeys) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return null;
  const keys = Object.keys(body);
  if (
    keys.length !== expectedKeys.length ||
    expectedKeys.some((key) => !keys.includes(key))
  ) {
    return null;
  }
  return body;
}

function keyedDigest(secret, value) {
  return createHmac('sha256', secret).update(value).digest('hex');
}

function hashOtp(secret, phoneHash, otp) {
  return keyedDigest(secret, `${phoneHash}:${otp}`);
}

function sameDigest(left, right) {
  const expected = Buffer.from(left, 'hex');
  const provided = Buffer.from(right, 'hex');
  return (
    expected.length === provided.length &&
    timingSafeEqual(expected, provided)
  );
}

function isConfigured(config) {
  return (
    typeof config.customerOtpPepper === 'string' &&
    Buffer.byteLength(config.customerOtpPepper, 'utf8') >= 32 &&
    typeof config.customerSessionSecret === 'string' &&
    Buffer.byteLength(config.customerSessionSecret, 'utf8') >= 32 &&
    config.whatsapp
  );
}

function timestampSeconds(value) {
  return Math.floor(new Date(value).getTime() / 1000);
}

async function checkAndIncrementLimit(client, {
  scope,
  subjectHash,
  nowSeconds,
  windowSeconds,
  maxRequests,
  cooldownSeconds = 0,
}) {
  await client.query(
    `INSERT INTO app.customer_auth_rate_limits
       (scope, subject_hash, window_started_at, request_count,
        last_requested_at, updated_at)
     VALUES ($1, $2, to_timestamp($3), 0,
             to_timestamp($3) - interval '1 day', to_timestamp($3))
     ON CONFLICT (scope, subject_hash) DO NOTHING`,
    [scope, subjectHash, nowSeconds],
  );
  const result = await client.query(
    `SELECT window_started_at, request_count, last_requested_at
     FROM app.customer_auth_rate_limits
     WHERE scope = $1 AND subject_hash = $2
     FOR UPDATE`,
    [scope, subjectHash],
  );
  const current = result.rows[0];
  const windowStartedAt = timestampSeconds(current.window_started_at);
  const lastRequestedAt = timestampSeconds(current.last_requested_at);
  const inWindow = nowSeconds - windowStartedAt < windowSeconds;
  const requestCount = inWindow ? Number(current.request_count) : 0;
  const cooldownRemaining = cooldownSeconds - (nowSeconds - lastRequestedAt);
  const windowRemaining = windowSeconds - (nowSeconds - windowStartedAt);
  if (cooldownRemaining > 0 || requestCount >= maxRequests) {
    throw new AuthFlowError(
      429,
      'OTP_RATE_LIMITED',
      'Too many verification requests. Try again later.',
      Math.max(
        1,
        cooldownRemaining > 0 ? cooldownRemaining : windowRemaining,
      ),
    );
  }

  const nextWindowStartedAt = inWindow ? windowStartedAt : nowSeconds;
  await client.query(
    `UPDATE app.customer_auth_rate_limits
     SET window_started_at = to_timestamp($3),
         request_count = $4,
         last_requested_at = to_timestamp($5),
         updated_at = to_timestamp($5)
     WHERE scope = $1 AND subject_hash = $2`,
    [scope, subjectHash, nextWindowStartedAt, requestCount + 1, nowSeconds],
  );
}

async function withTransaction(databasePool, operation) {
  const client = await databasePool.connect();
  let begun = false;
  try {
    await client.query('BEGIN');
    begun = true;
    const result = await operation(client);
    await client.query('COMMIT');
    begun = false;
    return result;
  } catch (error) {
    if (begun) await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

function createCustomerOtpAuth({
  databasePool,
  config,
  provider = createWhatsAppOtpProvider({ config }),
  now = () => Math.floor(Date.now() / 1000),
  logger = console,
}) {
  const router = express.Router();

  router.post('/auth/otp/request', async (req, res, next) => {
    if (!isConfigured(config) || !databasePool) {
      return res.status(503).json({
        error: {
          code: 'OTP_AUTH_UNAVAILABLE',
          message: 'Customer verification is temporarily unavailable.',
        },
      });
    }
    const body = parseRequestBody(req.body, ['phoneNumber']);
    const phone = body && normalizePhone(body.phoneNumber);
    if (!phone) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'Enter a valid Indian mobile number.',
        },
      });
    }

    const phoneHash = keyedDigest(config.customerOtpPepper, phone.e164);
    const requestIp = req.ip ?? req.socket.remoteAddress ?? 'unknown';
    const ipHash = keyedDigest(config.customerOtpPepper, requestIp);
    const nowSeconds = now();
    const otp = randomInt(0, 10 ** OTP_LENGTH)
      .toString()
      .padStart(OTP_LENGTH, '0');
    const otpHash = hashOtp(config.customerOtpPepper, phoneHash, otp);
    const challengeId = randomUUID();

    try {
      await withTransaction(databasePool, async (client) => {
        await client.query(
          `DELETE FROM app.customer_auth_rate_limits
           WHERE updated_at < to_timestamp($1) - interval '7 days'`,
          [nowSeconds],
        );
        await checkAndIncrementLimit(client, {
          scope: 'phone',
          subjectHash: phoneHash,
          nowSeconds,
          windowSeconds: PHONE_WINDOW_SECONDS,
          maxRequests: PHONE_MAX_REQUESTS,
          cooldownSeconds: RESEND_COOLDOWN_SECONDS,
        });
        await checkAndIncrementLimit(client, {
          scope: 'ip',
          subjectHash: ipHash,
          nowSeconds,
          windowSeconds: IP_WINDOW_SECONDS,
          maxRequests: IP_MAX_REQUESTS,
        });
        await client.query(
          `DELETE FROM app.customer_otp_challenges
           WHERE expires_at < to_timestamp($1) - interval '1 day'`,
          [nowSeconds],
        );
        await client.query(
          `INSERT INTO app.customer_otp_challenges
             (id, phone_hash, otp_hash, expires_at, attempt_count,
              provider_message_id, delivery_accepted_at, consumed_at, created_at)
           VALUES ($1, $2, $3, to_timestamp($4), 0, NULL, NULL, NULL,
                   to_timestamp($5))
           ON CONFLICT (phone_hash) DO UPDATE
           SET id = EXCLUDED.id,
               otp_hash = EXCLUDED.otp_hash,
               expires_at = EXCLUDED.expires_at,
               attempt_count = 0,
               provider_message_id = NULL,
               delivery_accepted_at = NULL,
               consumed_at = NULL,
               created_at = EXCLUDED.created_at`,
          [
            challengeId,
            phoneHash,
            otpHash,
            nowSeconds + OTP_LIFETIME_SECONDS,
            nowSeconds,
          ],
        );
      });
    } catch (error) {
      if (error instanceof AuthFlowError) {
        if (error.retryAfterSeconds) {
          res.set('Retry-After', `${error.retryAfterSeconds}`);
        }
        return res.status(error.status).json({
          error: { code: error.code, message: error.message },
        });
      }
      return next(error);
    }

    try {
      const providerMessageId = await provider.send({
        phoneNumber: phone.whatsappNumber,
        otp,
      });
      if (
        typeof providerMessageId !== 'string' ||
        !providerMessageId.startsWith('wamid.')
      ) {
        throw new Error('WhatsApp did not confirm message acceptance.');
      }
      const accepted = await databasePool.query(
        `UPDATE app.customer_otp_challenges
         SET provider_message_id = $2,
             delivery_accepted_at = to_timestamp($3)
         WHERE id = $1 AND consumed_at IS NULL`,
        [challengeId, providerMessageId, now()],
      );
      if (accepted.rowCount !== 1) {
        throw new Error('Unable to activate the customer OTP challenge.');
      }
    } catch (error) {
      try {
        await databasePool.query(
          `UPDATE app.customer_otp_challenges
           SET consumed_at = to_timestamp($2)
           WHERE id = $1 AND consumed_at IS NULL`,
          [challengeId, now()],
        );
      } catch (invalidateError) {
        return next(invalidateError);
      }
      logger.warn('Customer OTP delivery failed.', {
        errorName: error?.name ?? 'Error',
      });
      return res.status(503).json({
        error: {
          code: 'OTP_DELIVERY_FAILED',
          message: 'The verification message could not be accepted. Try again later.',
        },
      });
    }

    return res.status(202).json({
      data: {
        message: 'If this number can receive verification messages, a code may be sent.',
        expiresIn: OTP_LIFETIME_SECONDS,
        resendAfter: RESEND_COOLDOWN_SECONDS,
      },
    });
  });

  router.post('/auth/otp/verify', async (req, res, next) => {
    if (!isConfigured(config) || !databasePool) {
      return res.status(503).json({
        error: {
          code: 'OTP_AUTH_UNAVAILABLE',
          message: 'Customer verification is temporarily unavailable.',
        },
      });
    }
    const body = parseRequestBody(req.body, ['phoneNumber', 'otp']);
    const phone = body && normalizePhone(body.phoneNumber);
    if (!phone || typeof body.otp !== 'string' || !/^\d{6}$/.test(body.otp)) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'Enter a valid Indian mobile number and six-digit code.',
        },
      });
    }
    const phoneHash = keyedDigest(config.customerOtpPepper, phone.e164);
    const suppliedHash = hashOtp(
      config.customerOtpPepper,
      phoneHash,
      body.otp,
    );
    const nowSeconds = now();

    try {
      const verification = await withTransaction(
        databasePool,
        async (client) => {
          const challengeResult = await client.query(
            `SELECT id, otp_hash, expires_at, attempt_count,
                    delivery_accepted_at, consumed_at
             FROM app.customer_otp_challenges
             WHERE phone_hash = $1
             FOR UPDATE`,
            [phoneHash],
          );
          const challenge = challengeResult.rows[0];
          if (
            !challenge ||
            challenge.consumed_at ||
            !challenge.delivery_accepted_at ||
            timestampSeconds(challenge.expires_at) <= nowSeconds ||
            Number(challenge.attempt_count) >= OTP_MAX_ATTEMPTS
          ) {
            return { invalid: true };
          }
          const expectedHash = String(challenge.otp_hash).trim();
          if (!sameDigest(expectedHash, suppliedHash)) {
            await client.query(
              `UPDATE app.customer_otp_challenges
               SET attempt_count = attempt_count + 1
               WHERE id = $1`,
              [challenge.id],
            );
            return { invalid: true };
          }

          const customerResult = await client.query(
            `SELECT u.id, u.status, u.system_role, c.user_id AS customer_user_id
             FROM app.users AS u
             LEFT JOIN app.customers AS c ON c.user_id = u.id
             WHERE regexp_replace(u.phone, '[^0-9]', '', 'g') = ANY($1::text[])
             LIMIT 2`,
            [phone.variants],
          );
          let userId;
          if (customerResult.rows.length === 1) {
            const customer = customerResult.rows[0];
            if (
              customer.system_role !== 'customer' ||
              customer.status !== 'active' ||
              customer.customer_user_id !== customer.id
            ) {
              await client.query(
                `UPDATE app.customer_otp_challenges
                 SET consumed_at = to_timestamp($2)
                 WHERE id = $1`,
                [challenge.id, nowSeconds],
              );
              return { invalid: true };
            }
            userId = customer.id;
          } else if (customerResult.rows.length === 0) {
            userId = randomUUID();
            await client.query(
              `INSERT INTO app.users (id, phone, display_name, system_role)
               VALUES ($1, $2, 'Customer', 'customer')`,
              [userId, phone.e164],
            );
            await client.query(
              'INSERT INTO app.customers (user_id) VALUES ($1)',
              [userId],
            );
          } else {
            await client.query(
              `UPDATE app.customer_otp_challenges
               SET consumed_at = to_timestamp($2)
               WHERE id = $1`,
              [challenge.id, nowSeconds],
            );
            return { invalid: true };
          }

          await client.query(
            `UPDATE app.customer_otp_challenges
             SET consumed_at = to_timestamp($2)
             WHERE id = $1`,
            [challenge.id, nowSeconds],
          );
          return { userId };
        },
      );
      if (verification.invalid) {
        return res.status(401).json({
          error: {
            code: 'INVALID_OTP',
            message: 'The verification code is invalid or expired.',
          },
        });
      }

      return res.status(200).json({
        data: {
          accessToken: signCustomerToken(
            verification.userId,
            config.customerSessionSecret,
            nowSeconds,
            CUSTOMER_TOKEN_ISSUER,
          ),
          tokenType: 'Bearer',
          expiresIn: TOKEN_LIFETIME_SECONDS,
        },
      });
    } catch (error) {
      if (error instanceof AuthFlowError) {
        return res.status(error.status).json({
          error: { code: error.code, message: error.message },
        });
      }
      return next(error);
    }
  });

  return router;
}

module.exports = {
  OTP_ATTEMPTS: OTP_MAX_ATTEMPTS,
  OTP_LIFETIME_SECONDS,
  RESEND_COOLDOWN_SECONDS,
  createCustomerOtpAuth,
  hashOtp,
  normalizePhone,
};
