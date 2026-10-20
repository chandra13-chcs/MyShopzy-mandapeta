const assert = require('node:assert/strict');
const test = require('node:test');

const { loadConfig } = require('../../src/config/env');

test('uses development defaults and permits health-only configuration', () => {
  assert.deepEqual(loadConfig({}), {
    port: 3000,
    nodeEnv: 'development',
    database: null,
    developmentCustomerOtp: null,
    developmentCustomerSessionSecret: null,
    customerOtpPepper: null,
    customerSessionSecret: null,
    whatsapp: null,
    auth0Admin: null,
    auth0Partner: null,
    superAdminOrigin: null,
    partnerPortalOrigins: ['http://localhost:5173'],
  });

  test('parses complete backend-only customer OTP provider settings', () => {
    const config = loadConfig({
      CUSTOMER_OTP_PEPPER: 'otp-pepper-with-at-least-thirty-two-bytes',
      CUSTOMER_SESSION_SECRET: 'customer-session-secret-of-at-least-thirty-two',
      WHATSAPP_ACCESS_TOKEN: 'backend-test-access-token',
      WHATSAPP_PHONE_NUMBER_ID: '1029384756',
      WHATSAPP_OTP_TEMPLATE_NAME: 'authentication_code',
      WHATSAPP_OTP_TEMPLATE_LANGUAGE: 'en_US',
    });

    assert.equal(config.customerOtpPepper, 'otp-pepper-with-at-least-thirty-two-bytes');
    assert.equal(
      config.customerSessionSecret,
      'customer-session-secret-of-at-least-thirty-two',
    );
    assert.deepEqual(config.whatsapp, {
      accessToken: 'backend-test-access-token',
      phoneNumberId: '1029384756',
      templateName: 'authentication_code',
      templateLanguage: 'en_US',
      graphApiVersion: 'v25.0',
    });
  });

  test('rejects incomplete and weak customer OTP configuration', () => {
    assert.throws(
      () => loadConfig({ WHATSAPP_ACCESS_TOKEN: 'backend-test-access-token' }),
      /Customer OTP authentication configuration is incomplete/,
    );
    assert.throws(
      () =>
        loadConfig({
          CUSTOMER_OTP_PEPPER: 'too-short',
          CUSTOMER_SESSION_SECRET: 'customer-session-secret-of-at-least-thirty-two',
          WHATSAPP_ACCESS_TOKEN: 'backend-test-access-token',
          WHATSAPP_PHONE_NUMBER_ID: '1029384756',
          WHATSAPP_OTP_TEMPLATE_NAME: 'authentication_code',
          WHATSAPP_OTP_TEMPLATE_LANGUAGE: 'en_US',
        }),
      /must be at least 32 bytes/,
    );
  });
});

test('parses a complete PostgreSQL configuration without changing values', () => {
  const config = loadConfig({
    PORT: '3100',
    NODE_ENV: 'test',
    PGHOST: 'db.example.test',
    PGPORT: '5433',
    PGDATABASE: 'myshopzy',
    PGUSER: 'app_user',
    PGPASSWORD: 'test-only-password',
    DEVELOPMENT_CUSTOMER_OTP: '123456',
    DEVELOPMENT_CUSTOMER_SESSION_SECRET: 'test-session-secret-at-least-32-bytes-long',
  });

  assert.equal(config.port, 3100);
  assert.equal(config.nodeEnv, 'test');
  assert.equal(config.developmentCustomerOtp, '123456');
  assert.equal(
    config.developmentCustomerSessionSecret,
    'test-session-secret-at-least-32-bytes-long',
  );
  assert.deepEqual(config.database, {
    host: 'db.example.test',
    port: 5433,
    database: 'myshopzy',
    user: 'app_user',
    password: 'test-only-password',
  });
  assert.equal(Object.isFrozen(config), true);
  assert.equal(Object.isFrozen(config.database), true);
});

test('rejects invalid HTTP and PostgreSQL ports without echoing values', () => {
  assert.throws(
    () => loadConfig({ PORT: '3000;unexpected' }),
    { message: 'PORT must be an integer between 1 and 65535.' },
  );

  assert.throws(
    () =>
      loadConfig({
        PGHOST: 'db.example.test',
        PGPORT: '70000',
        PGDATABASE: 'myshopzy',
        PGUSER: 'app_user',
        PGPASSWORD: 'sensitive-test-value',
      }),
    { message: 'PGPORT must be an integer between 1 and 65535.' },
  );
});

test('rejects PostgreSQL database names other than myshopzy', () => {
  for (const database of ['MyShopzy', 'delivery_app', 'myshopzy_test']) {
    assert.throws(
      () =>
        loadConfig({
          PGHOST: 'db.example.test',
          PGPORT: '5432',
          PGDATABASE: database,
          PGUSER: 'app_user',
          PGPASSWORD: 'test-only-password',
        }),
      { message: 'PGDATABASE must be set to myshopzy.' },
    );
  }
});

test('rejects partial PostgreSQL configuration and only names missing keys', () => {
  assert.throws(
    () =>
      loadConfig({
        PGHOST: 'db.example.test',
        PGPASSWORD: 'sensitive-test-value',
      }),
    (error) => {
      assert.equal(
        error.message,
        'PostgreSQL configuration is incomplete. Set: PGPORT, PGDATABASE, PGUSER.',
      );
      assert.equal(error.message.includes('sensitive-test-value'), false);
      return true;
    },
  );
});

test('enables Auth0 admin configuration only when issuer, audience and origin are set', () => {
  assert.throws(
    () => loadConfig({ AUTH0_ISSUER_URL: 'https://tenant.example.test/' }),
    /Set both AUTH0_ISSUER_URL and AUTH0_AUDIENCE/,
  );

  const config = loadConfig({
    AUTH0_ISSUER_URL: 'https://tenant.example.test/',
    AUTH0_AUDIENCE: 'https://api.example.test',
    AUTH0_ADMIN_USER_ID_CLAIM: 'https://claims.example.test/admin_user_id',
    SUPER_ADMIN_ORIGIN: 'http://localhost:5173',
  });
  assert.deepEqual(config.auth0Admin, {
    issuerUrl: 'https://tenant.example.test/',
    audience: 'https://api.example.test',
    adminUserIdClaim: 'https://claims.example.test/admin_user_id',
  });
  assert.deepEqual(config.auth0Partner, {
    issuerUrl: 'https://tenant.example.test/',
    audience: 'https://api.example.test',
    emailClaim: 'email',
    emailVerifiedClaim: 'email_verified',
  });
  assert.equal(config.superAdminOrigin, 'http://localhost:5173');
});

test('enables partner auth independently and keeps admin auth disabled without its identity claim', () => {
  const config = loadConfig({
    AUTH0_ISSUER_URL: 'https://tenant.example.test/',
    AUTH0_AUDIENCE: 'https://api.example.test',
  });
  assert.equal(config.auth0Admin, null);
  assert.deepEqual(config.auth0Partner, {
    issuerUrl: 'https://tenant.example.test/',
    audience: 'https://api.example.test',
    emailClaim: 'email',
    emailVerifiedClaim: 'email_verified',
  });
  assert.equal(config.superAdminOrigin, null);
});

test('supports namespaced Auth0 email claims for partner identity lookup', () => {
  const config = loadConfig({
    AUTH0_ISSUER_URL: 'https://tenant.example.test/',
    AUTH0_AUDIENCE: 'https://api.example.test',
    AUTH0_PARTNER_EMAIL_CLAIM: 'https://claims.example.test/email',
    AUTH0_PARTNER_EMAIL_VERIFIED_CLAIM:
      'https://claims.example.test/email_verified',
  });
  assert.deepEqual(config.auth0Partner, {
    issuerUrl: 'https://tenant.example.test/',
    audience: 'https://api.example.test',
    emailClaim: 'https://claims.example.test/email',
    emailVerifiedClaim: 'https://claims.example.test/email_verified',
  });
});

test('parses partner portal origins and rejects wildcard CORS origins', () => {
  const config = loadConfig({
    PARTNER_PORTAL_ORIGINS: 'http://localhost:5174,https://partner.example.test',
  });
  assert.deepEqual(config.partnerPortalOrigins, [
    'http://localhost:5174',
    'https://partner.example.test',
  ]);
  assert.throws(
    () => loadConfig({ PARTNER_PORTAL_ORIGINS: '*' }),
    /PARTNER_PORTAL_ORIGINS must contain HTTPS origins or localhost origins/,
  );
});

test('rejects insecure Auth0 issuers and non-origin Super Admin URLs', () => {
  assert.throws(
    () => loadConfig({
      AUTH0_ISSUER_URL: 'http://tenant.example.test/',
      AUTH0_AUDIENCE: 'https://api.example.test',
      AUTH0_ADMIN_USER_ID_CLAIM: 'https://claims.example.test/admin_user_id',
      SUPER_ADMIN_ORIGIN: 'https://admin.example.test',
    }),
    /AUTH0_ISSUER_URL must be an HTTPS Auth0 issuer origin/,
  );
  assert.throws(
    () => loadConfig({
      AUTH0_ISSUER_URL: 'https://tenant.example.test/',
      AUTH0_AUDIENCE: 'https://api.example.test',
      AUTH0_ADMIN_USER_ID_CLAIM: 'https://claims.example.test/admin_user_id',
      SUPER_ADMIN_ORIGIN: 'https://admin.example.test/path',
    }),
    /SUPER_ADMIN_ORIGIN must be a valid HTTPS origin/,
  );
});
