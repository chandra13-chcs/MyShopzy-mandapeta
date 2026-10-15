const POSTGRES_ENV_KEYS = [
  'PGHOST',
  'PGPORT',
  'PGDATABASE',
  'PGUSER',
  'PGPASSWORD',
];

function loadConfig(env = process.env) {
  const rawPort = env.PORT || '3000';
  const port = Number(rawPort);

  if (!/^\d+$/.test(rawPort) || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }

  const configuredPostgresKeys = POSTGRES_ENV_KEYS.filter(
    (key) => env[key] !== undefined && env[key] !== '',
  );

  let database = null;

  if (configuredPostgresKeys.length > 0) {
    const missingKeys = POSTGRES_ENV_KEYS.filter(
      (key) => env[key] === undefined || env[key] === '',
    );
    if (missingKeys.length > 0) {
      throw new Error(
        `PostgreSQL configuration is incomplete. Set: ${missingKeys.join(', ')}.`,
      );
    }

    const databasePort = Number(env.PGPORT);
    if (
      !/^\d+$/.test(env.PGPORT) ||
      !Number.isInteger(databasePort) ||
      databasePort < 1 ||
      databasePort > 65535
    ) {
      throw new Error('PGPORT must be an integer between 1 and 65535.');
    }

    database = Object.freeze({
      host: env.PGHOST,
      port: databasePort,
      database: env.PGDATABASE,
      user: env.PGUSER,
      password: env.PGPASSWORD,
    });
  }

  const auth0IssuerUrl = env.AUTH0_ISSUER_URL?.trim() || null;
  const auth0Audience = env.AUTH0_AUDIENCE?.trim() || null;
  const auth0AdminUserIdClaim =
    env.AUTH0_ADMIN_USER_ID_CLAIM?.trim() || null;
  const superAdminOrigin = env.SUPER_ADMIN_ORIGIN?.trim() || null;
  const auth0ConfigProvided = Boolean(
    auth0IssuerUrl ||
      auth0Audience ||
      superAdminOrigin,
  );
  let auth0Admin = null;

  if (auth0ConfigProvided) {
    const missingKeys = [
      ['AUTH0_ISSUER_URL', auth0IssuerUrl],
      ['AUTH0_AUDIENCE', auth0Audience],
      ['SUPER_ADMIN_ORIGIN', superAdminOrigin],
    ].filter(([, value]) => !value).map(([key]) => key);
    if (missingKeys.length > 0) {
      throw new Error(
        `Super Admin authentication configuration is incomplete. Set: ${missingKeys.join(', ')}.`,
      );
    }

    let issuer;
    let origin;
    try {
      issuer = new URL(auth0IssuerUrl);
      origin = new URL(superAdminOrigin);
    } catch {
      throw new Error('Auth0 issuer and Super Admin origin must be valid URLs.');
    }
    if (
      issuer.protocol !== 'https:' ||
      issuer.username ||
      issuer.password ||
      issuer.search ||
      issuer.hash ||
      issuer.pathname !== '/'
    ) {
      throw new Error('AUTH0_ISSUER_URL must be an HTTPS Auth0 issuer origin.');
    }
    if (auth0AdminUserIdClaim) {
      let adminUserIdClaim;
      try {
        adminUserIdClaim = new URL(auth0AdminUserIdClaim);
      } catch {
        throw new Error('AUTH0_ADMIN_USER_ID_CLAIM must be an HTTPS claim namespace URI.');
      }
      if (adminUserIdClaim.protocol !== 'https:') {
        throw new Error('AUTH0_ADMIN_USER_ID_CLAIM must be an HTTPS claim namespace URI.');
      }
    }
    if (
      origin.origin !== superAdminOrigin.replace(/\/+$/, '') ||
      (origin.protocol !== 'https:' &&
        !(origin.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(origin.hostname)))
    ) {
      throw new Error('SUPER_ADMIN_ORIGIN must be a valid HTTPS origin.');
    }

    if (auth0AdminUserIdClaim) {
      auth0Admin = Object.freeze({
        issuerUrl: issuer.href,
        audience: auth0Audience,
        adminUserIdClaim: auth0AdminUserIdClaim,
      });
    }
  }

  return Object.freeze({
    port,
    nodeEnv: env.NODE_ENV || 'development',
    database,
    developmentCustomerOtp: env.DEVELOPMENT_CUSTOMER_OTP || null,
    developmentCustomerSessionSecret:
      env.DEVELOPMENT_CUSTOMER_SESSION_SECRET || null,
    auth0Admin,
    superAdminOrigin,
  });
}

module.exports = { loadConfig };
