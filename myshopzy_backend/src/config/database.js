const { Pool } = require('pg');

function createDatabasePool(databaseConfig, { PoolClass = Pool, onError } = {}) {
  if (!databaseConfig) return null;

  const pool = new PoolClass({
    host: databaseConfig.host,
    port: databaseConfig.port,
    database: databaseConfig.database,
    user: databaseConfig.user,
    password: databaseConfig.password,
  });

  if (onError) {
    pool.on('error', () => onError());
  }

  return pool;
}

async function isDatabaseReady(pool) {
  if (!pool) return false;

  try {
    await pool.query('SELECT 1');
    return true;
  } catch {
    return false;
  }
}

module.exports = { createDatabasePool, isDatabaseReady };
