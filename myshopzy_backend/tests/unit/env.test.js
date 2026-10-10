const assert = require('node:assert/strict');
const test = require('node:test');

const { loadConfig } = require('../../src/config/env');

test('uses development defaults and permits health-only configuration', () => {
  assert.deepEqual(loadConfig({}), {
    port: 3000,
    nodeEnv: 'development',
    database: null,
  });
});

test('parses a complete PostgreSQL configuration without changing values', () => {
  const config = loadConfig({
    PORT: '3100',
    NODE_ENV: 'test',
    PGHOST: 'db.example.test',
    PGPORT: '5433',
    PGDATABASE: 'myshopzy_test',
    PGUSER: 'app_user',
    PGPASSWORD: 'test-only-password',
  });

  assert.equal(config.port, 3100);
  assert.equal(config.nodeEnv, 'test');
  assert.deepEqual(config.database, {
    host: 'db.example.test',
    port: 5433,
    database: 'myshopzy_test',
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
