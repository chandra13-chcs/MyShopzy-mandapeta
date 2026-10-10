const { createApp } = require('./app');
const { createDatabasePool } = require('./config/database');
const { loadConfig } = require('./config/env');

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
  processObject = process,
  logger = console,
} = {}) {
  const pool = createDatabasePool(config.database, {
    ...(PoolClass ? { PoolClass } : {}),
    onError: () => logger.error('Unexpected PostgreSQL pool error.'),
  });
  const app = createApp({ databasePool: pool });
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
