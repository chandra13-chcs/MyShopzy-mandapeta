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

  return Object.freeze({
    port,
    nodeEnv: env.NODE_ENV || 'development',
    database,
    developmentCustomerOtp: env.DEVELOPMENT_CUSTOMER_OTP || null,
    developmentCustomerSessionSecret:
      env.DEVELOPMENT_CUSTOMER_SESSION_SECRET || null,
  });
}

module.exports = { loadConfig };
