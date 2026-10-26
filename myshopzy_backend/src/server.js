const { createApp } = require('./app');
const { createDatabasePool } = require('./config/database');
const { loadConfig } = require('./config/env');
const {
  createCustomerAuthenticator,
} = require('./modules/customer-auth/customer-session');
const {
  createAuth0AdminAuthenticator,
} = require('./modules/admin-read/auth0-authentication');
const {
  createPartnerAuthenticator,
} = require('./modules/partner-types/auth0-authentication');
const { mockRiderAuth } = require('./middleware/mock-rider-auth');
const { createDistanceClient } = require('./modules/delivery-fee/distance');

function shutdownServer(server, pool) {
  return new Promise((resolve, reject) => {
    server.close(async (serverError) => {
      let poolError;
      if (pool) {
        try {
          await pool.end();
        } catch (error) {
          poolError = error;
        }
      }

      if (serverError || poolError) {
        reject(serverError || poolError);
      } else {
        resolve();
      }
    });
  });
}

function startServer({
  config = loadConfig(),
  PoolClass,
  authenticateRider = null,
  processObject = process,
  logger = console,
} = {}) {
  const pool = createDatabasePool(config.database, {
    ...(PoolClass ? { PoolClass } : {}),
    onError: () => logger.error('Unexpected PostgreSQL pool error.'),
  });
  if (config.nodeEnv === 'production' && config.routingProvider === 'fake') {
    throw new Error('ROUTING_PROVIDER=fake cannot be used in production.');
  }
  const deliveryDistanceClient = createDistanceClient({
    provider: config.routingProvider,
    apiKey: config.routingApiKey,
  });
  const authenticateAdmin = config.auth0Admin && config.superAdminOrigin && pool
    ? createAuth0AdminAuthenticator({
        databasePool: pool,
        ...config.auth0Admin,
      })
    : null;
  const authenticatePartner = config.auth0Partner && pool
    ? createPartnerAuthenticator({
        databasePool: pool,
        ...config.auth0Partner,
      })
    : null;
  const app = createApp({
    databasePool: pool,
    deliveryDistanceClient,
    authenticateCustomer: createCustomerAuthenticator({
      databasePool: pool,
      config,
    }),
    authenticateRider:
      authenticateRider ??
      (config.nodeEnv === 'production' ? null : mockRiderAuth),
    supportPhone: config.supportPhone,
    supportEscalationMinutes: config.supportEscalationMinutes,
    authenticateAdmin,
    authenticatePartner,
    nodeEnv: config.nodeEnv,
    superAdminOrigin: authenticateAdmin ? config.superAdminOrigin : null,
    partnerPortalOrigins: config.partnerPortalOrigins,
    customerAppOrigins: config.customerAppOrigins,
  });
  const server = app.listen(config.port, () => {
    logger.log(`MyShopzy backend listening on port ${config.port}`);
  });

  server.on('error', () => {
    logger.error('Unable to start MyShopzy backend.');
    processObject.exitCode = 1;
  });

  let shuttingDown = false;
  const shutdown = () => {
    if (shuttingDown) return;
    shuttingDown = true;
    shutdownServer(server, pool).catch(() => {
      logger.error('Unable to shut down MyShopzy backend cleanly.');
      processObject.exitCode = 1;
    });
  };

  processObject.on('SIGINT', shutdown);
  processObject.on('SIGTERM', shutdown);

  return { server, pool, shutdown };
}

if (require.main === module) {
  require('dotenv').config();
  startServer();
}

module.exports = { startServer, shutdownServer };
