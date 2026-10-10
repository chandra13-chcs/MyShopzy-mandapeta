const { createHash } = require('node:crypto');
const { readdir, readFile } = require('node:fs/promises');
const path = require('node:path');
const { createDatabasePool } = require('../config/database');
const { loadConfig } = require('../config/env');

const MIGRATION_LOCK = [1297303369, 1];
const MIGRATION_FILE_PATTERN = /^(\d{3})_([a-z0-9_]+)\.sql$/;
const MIGRATION_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version text PRIMARY KEY,
    name text NOT NULL,
    checksum char(64) NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
  )
`;

async function readMigrations(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const sqlFiles = entries.filter(
    (entry) => entry.isFile() && path.extname(entry.name).toLowerCase() === '.sql',
  );
  const unexpectedSqlFiles = sqlFiles
    .map((entry) => entry.name)
    .filter((name) => !MIGRATION_FILE_PATTERN.test(name));

  if (unexpectedSqlFiles.length > 0) {
    throw new Error(
      `Unexpected SQL migration filename(s): ${unexpectedSqlFiles.join(', ')}.`,
    );
  }

  const files = sqlFiles.map((entry) => entry.name).sort();
  const migrations = [];

  for (const name of files) {
    const match = MIGRATION_FILE_PATTERN.exec(name);
    const sql = await readFile(path.join(directory, name), 'utf8');
    migrations.push({
      version: match[1],
      name,
      sql,
      checksum: createHash('sha256').update(sql).digest('hex'),
    });
  }

  for (let index = 1; index < migrations.length; index++) {
    if (migrations[index - 1].version === migrations[index].version) {
      throw new Error(`Duplicate migration version ${migrations[index].version}.`);
    }
  }

  return migrations;
}

async function runMigrations(pool, { directory = path.resolve(__dirname, '../../database/migrations') } = {}) {
  const migrations = await readMigrations(directory);
  const client = await pool.connect();
  let lockAcquired = false;

  try {
    await client.query('SELECT pg_advisory_lock($1, $2)', MIGRATION_LOCK);
    lockAcquired = true;
    await client.query(MIGRATION_TABLE_SQL);

    for (const migration of migrations) {
      const applied = await client.query(
        'SELECT checksum FROM public.schema_migrations WHERE version = $1',
        [migration.version],
      );

      if (applied.rowCount > 0) {
        if (applied.rows[0].checksum.trim() !== migration.checksum) {
          throw new Error(
            `Applied migration ${migration.version} has changed; refusing to continue.`,
          );
        }
        continue;
      }

      await client.query('BEGIN');
      try {
        await client.query(migration.sql);
        await client.query(
          `INSERT INTO public.schema_migrations (version, name, checksum)
           VALUES ($1, $2, $3)`,
          [migration.version, migration.name, migration.checksum],
        );
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    }

    return migrations.length;
  } finally {
    if (lockAcquired) {
      try {
        await client.query('SELECT pg_advisory_unlock($1, $2)', MIGRATION_LOCK);
      } finally {
        client.release();
      }
    } else {
      client.release();
    }
  }
}

async function main() {
  require('dotenv').config();
  const config = loadConfig();
  if (!config.database) {
    throw new Error('PostgreSQL configuration is required to run migrations.');
  }

  const pool = createDatabasePool(config.database);
  try {
    const count = await runMigrations(pool);
    console.log(`Migration check complete (${count} migration file(s) found).`);
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  main().catch(() => {
    console.error('Migration command failed. No database details were logged.');
    process.exitCode = 1;
  });
}

module.exports = { readMigrations, runMigrations };
