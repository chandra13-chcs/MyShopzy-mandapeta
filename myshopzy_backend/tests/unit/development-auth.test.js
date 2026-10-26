const assert = require('node:assert/strict');
const { EventEmitter, once } = require('node:events');
const test = require('node:test');
const express = require('express');

const {
  createDevelopmentCustomerAuth,
  TOKEN_LIFETIME_SECONDS,
} = require('../../src/modules/customer-auth/development-auth');
const { startServer } = require('../../src/server');

const customerId = '27dcad4a-f166-4fc8-a224-3d1c099dd459';
const config = {
  nodeEnv: 'test',
  developmentCustomerOtp: '245810',
  developmentCustomerSessionSecret:
    'test-session-secret-with-more-than-thirty-two-bytes',
};

function createDatabase({ phoneMatches = true } = {}) {
  const queries = [];
  return {
    queries,
    async query(sql, params = []) {
      queries.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      if (sql.includes('FROM app.users AS u') && sql.includes('JOIN app.customers')) {
        const matches = phoneMatches && params[0].includes('9876543210');
        return {
          rows: matches ? [{ id: customerId }] : [],
          rowCount: matches ? 1 : 0,
        };
      }
      if (sql.includes('FROM app.customers AS c')) {
        return params[0] === customerId
          ? { rows: [{ user_id: customerId }], rowCount: 1 }
          : { rows: [], rowCount: 0 };
      }
      assert.fail(`Unexpected SQL in development-auth test: ${sql}`);
    },
  };
}

async function startTestServer(app) {
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve, reject) => {
    server.once('listening', resolve);
    server.once('error', reject);
  });
  const address = server.address();
  return {
    url: `http://127.0.0.1:${address.port}`,
    close: () => new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    }),
  };
}

function createTestApp({
  databasePool = createDatabase(),
  authConfig = config,
  now,
} = {}) {
  const auth = createDevelopmentCustomerAuth({
    databasePool,
    config: authConfig,
    ...(now ? { now } : {}),
  });
  const app = express();
  app.use(express.json());
  app.use('/api/v1', auth.router);
  app.get('/protected', auth.authenticateCustomer, (req, res) => {
    res.json({ customerUserId: req.auth.customerUserId });
  });
  return { app, databasePool };
}

test('valid OTP resolves the existing customer phone and issues a signed session', async () => {
  const { app, databasePool } = createTestApp();
  const running = await startTestServer(app);
  try {
    const response = await fetch(`${running.url}/api/v1/auth/development/verify-otp`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        phoneNumber: '+91 98765 43210',
        otp: '245810',
      }),
    });
    const result = await response.json();
    assert.equal(response.status, 200);
    assert.equal(result.data.tokenType, 'Bearer');
    assert.equal(result.data.expiresIn, TOKEN_LIFETIME_SECONDS);
    assert.equal(typeof result.data.accessToken, 'string');
    assert.equal(
      databasePool.queries[0].params[0].includes('9876543210'),
      true,
    );
    assert.equal(databasePool.queries[0].params[0].includes(customerId), false);
  } finally {
    await running.close();
  }
});

test('invalid OTP, unknown phone, and client-supplied customer ID never issue sessions', async () => {
  const matching = createTestApp();
  const unmatched = createTestApp({ databasePool: createDatabase({ phoneMatches: false }) });
  const matchingServer = await startTestServer(matching.app);
  const unmatchedServer = await startTestServer(unmatched.app);
  try {
    const invalidOtp = await fetch(
      `${matchingServer.url}/api/v1/auth/development/verify-otp`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ phoneNumber: '9876543210', otp: '000000' }),
      },
    );
    assert.equal(invalidOtp.status, 401);
    assert.equal(matching.databasePool.queries.length, 0);

    const unknownPhone = await fetch(
      `${unmatchedServer.url}/api/v1/auth/development/verify-otp`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ phoneNumber: '9876543210', otp: '245810' }),
      },
    );
    assert.equal(unknownPhone.status, 401);
    assert.equal((await unknownPhone.json()).data, undefined);

    const suppliedIdentity = await fetch(
      `${matchingServer.url}/api/v1/auth/development/verify-otp`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          phoneNumber: '9876543210',
          otp: '245810',
          customerId,
        }),
      },
    );
    assert.equal(suppliedIdentity.status, 400);
    assert.equal((await suppliedIdentity.json()).data, undefined);
  } finally {
    await Promise.all([matchingServer.close(), unmatchedServer.close()]);
  }
});

test('session middleware rejects absent, tampered, expired credentials and protects routes', async () => {
  let now = 2_000_000_000;
  const { app } = createTestApp({ now: () => now });
  const running = await startTestServer(app);
  try {
    const absent = await fetch(`${running.url}/protected`);
    assert.equal(absent.status, 401);

    const verification = await fetch(
      `${running.url}/api/v1/auth/development/verify-otp`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ phoneNumber: '9876543210', otp: '245810' }),
      },
    );
    assert.equal(verification.status, 200);
    const { accessToken } = (await verification.json()).data;

    const accepted = await fetch(`${running.url}/protected`, {
      headers: { authorization: `Bearer ${accessToken}` },
    });
    assert.equal(accepted.status, 200);
    assert.deepEqual(await accepted.json(), { customerUserId: customerId });

    const parts = accessToken.split('.');
    parts[2] = `${parts[2][0] === 'A' ? 'B' : 'A'}${parts[2].slice(1)}`;
    const tampered = await fetch(`${running.url}/protected`, {
      headers: { authorization: `Bearer ${parts.join('.')}` },
    });
    assert.equal(tampered.status, 401);

    now += TOKEN_LIFETIME_SECONDS;
    const expired = await fetch(`${running.url}/protected`, {
      headers: { authorization: `Bearer ${accessToken}` },
    });
    assert.equal(expired.status, 401);
  } finally {
    await running.close();
  }
});

test('production mode rejects development OTP and fails closed on protected routes', async () => {
  const { app } = createTestApp({
    authConfig: { ...config, nodeEnv: 'production' },
  });
  const running = await startTestServer(app);
  try {
    const login = await fetch(
      `${running.url}/api/v1/auth/development/verify-otp`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ phoneNumber: '9876543210', otp: '245810' }),
      },
    );
    assert.equal(login.status, 404);

    const protectedRequest = await fetch(`${running.url}/protected`, {
      headers: { authorization: 'Bearer any-token' },
    });
    assert.equal(protectedRequest.status, 401);
  } finally {
    await running.close();
  }
});

test('running server does not expose customer login and fails closed on private APIs', async () => {
  const processObject = new EventEmitter();
  const { server, shutdown } = startServer({
    config: {
      port: 0,
      nodeEnv: 'development',
      database: {
        host: 'localhost',
        port: 5432,
        database: 'test',
        user: 'test',
        password: 'test-only',
      },
    },
    processObject,
    logger: { log() {}, error() {} },
  });
  await once(server, 'listening');
  const url = `http://127.0.0.1:${server.address().port}`;
  try {
    const login = await fetch(`${url}/api/v1/auth/development/verify-otp`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ phoneNumber: '9876543210', otp: '245810' }),
    });
    assert.equal(login.status, 404);
    for (const [method, path] of [
      ['GET', '/api/v1/me/profile'],
      ['GET', '/api/v1/me/orders'],
      ['GET', '/api/v1/me/parcels'],
      ['GET', '/api/v1/me/addresses'],
      ['POST', '/api/v1/carts'],
      ['POST', '/api/v1/checkout/quote'],
      ['POST', '/api/v1/orders'],
    ]) {
      const response = await fetch(`${url}${path}`, {
        method,
        ...(method === 'POST'
          ? {
              headers: { 'content-type': 'application/json' },
              body: '{}',
            }
          : {}),
      });
      assert.equal(response.status, 401, path);
      assert.equal(
        (await response.json()).error.code,
        'AUTHENTICATION_REQUIRED',
        path,
      );
    }
  } finally {
    shutdown();
    await once(server, 'close');
  }
});
