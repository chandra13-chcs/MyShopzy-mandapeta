const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');
const {
  createDatabasePool,
  isDatabaseReady,
} = require('../../src/config/database');
const { shutdownServer } = require('../../src/server');

const databaseConfig = {
  host: 'db.example.test',
  port: 5432,
  database: 'myshopzy_test',
  user: 'app_user',
  password: 'test-only-password',
};

test('creates a pool from validated database settings and reports pool errors safely', () => {
  let poolOptions;
  let poolErrorHandler;
  let reportedErrors = 0;

  class MockPool extends EventEmitter {
    constructor(options) {
      super();
      poolOptions = options;
    }
  }

  const pool = createDatabasePool(databaseConfig, {
    PoolClass: MockPool,
    onError: () => reportedErrors++,
  });

  assert.deepEqual(poolOptions, databaseConfig);
  pool.emit('error', new Error('private database detail'));
  poolErrorHandler = pool.listeners('error')[0];
  assert.equal(typeof poolErrorHandler, 'function');
  assert.equal(reportedErrors, 1);
});

test('does not create a pool when PostgreSQL is not configured', () => {
  class UnexpectedPool {
    constructor() {
      assert.fail('Pool should not be constructed without database settings.');
    }
  }

  assert.equal(createDatabasePool(null, { PoolClass: UnexpectedPool }), null);
});

test('readiness uses SELECT 1 and contains query errors', async () => {
  const queries = [];
  const readyPool = {
    async query(sql) {
      queries.push(sql);
      return { rows: [{ '?column?': 1 }] };
    },
  };
  const failingPool = {
    async query() {
      throw new Error('private database detail');
    },
  };

  assert.equal(await isDatabaseReady(readyPool), true);
  assert.deepEqual(queries, ['SELECT 1']);
  assert.equal(await isDatabaseReady(failingPool), false);
  assert.equal(await isDatabaseReady(null), false);
});

test('keeps liveness compatible and readiness reports no internal details', async (t) => {
  const databasePool = {
    async query() {
      throw new Error('private database detail');
    },
  };
  const server = http.createServer(createApp({ databasePool }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  const healthResponse = await fetch(`${baseUrl}/health`);
  const readinessResponse = await fetch(`${baseUrl}/health/ready`);

  assert.equal(healthResponse.status, 200);
  assert.deepEqual(await healthResponse.json(), { status: 'ok' });
  assert.equal(readinessResponse.status, 503);
  assert.deepEqual(await readinessResponse.json(), { status: 'not_ready' });
});

test('readiness succeeds when the mocked database query succeeds', async (t) => {
  const databasePool = { query: async () => ({ rows: [{ '?column?': 1 }] }) };
  const server = http.createServer(createApp({ databasePool }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));

  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/health/ready`,
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ready' });
});

test('shutdown closes the HTTP server and PostgreSQL pool', async () => {
  const events = [];
  const server = {
    close(callback) {
      events.push('server');
      callback();
    },
  };
  const pool = {
    async end() {
      events.push('pool');
    },
  };

  await shutdownServer(server, pool);

  assert.deepEqual(events, ['server', 'pool']);
});
