const assert = require('node:assert/strict');
const { once } = require('node:events');
const test = require('node:test');
const express = require('express');
const {
  CUSTOMER_TOKEN_ISSUER,
  DEVELOPMENT_TOKEN_ISSUER,
  createCustomerAuthenticator,
  signCustomerToken,
} = require('../../src/modules/customer-auth/customer-session');
const {
  createCustomerOtpAuth,
  OTP_LIFETIME_SECONDS,
} = require('../../src/modules/customer-auth/otp-auth');

const config = {
  nodeEnv: 'test',
  customerOtpPepper: 'customer-otp-test-pepper-with-more-than-thirty-two-bytes',
  customerSessionSecret:
    'customer-session-test-secret-with-more-than-thirty-two-bytes',
  developmentCustomerSessionSecret: null,
  whatsapp: {
    accessToken: 'backend-test-token',
    phoneNumberId: '123456789',
    templateName: 'authentication_code',
    templateLanguage: 'en_US',
    graphApiVersion: 'v25.0',
  },
};
const existingCustomerId = '27dcad4a-f166-4fc8-a224-3d1c099dd459';

function copyState(state) {
  return {
    challenges: new Map(
      [...state.challenges].map(([key, value]) => [key, { ...value }]),
    ),
    rateLimits: new Map(
      [...state.rateLimits].map(([key, value]) => [key, { ...value }]),
    ),
    users: new Map([...state.users].map(([key, value]) => [key, { ...value }])),
    customers: new Set(state.customers),
  };
}

function createDatabase({ existingCustomer = false } = {}) {
  const state = {
    challenges: new Map(),
    rateLimits: new Map(),
    users: new Map(),
    customers: new Set(),
  };
  if (existingCustomer) {
    state.users.set(existingCustomerId, {
      id: existingCustomerId,
      phone: '+919876543210',
      displayName: 'Existing Customer',
      systemRole: 'customer',
      status: 'active',
    });
    state.customers.add(existingCustomerId);
  }
  const calls = [];
  let snapshot;

  async function query(sql, params = []) {
    const normalized = sql.replace(/\s+/g, ' ').trim();
    calls.push({ sql: normalized, params });
    if (normalized === 'BEGIN') {
      snapshot = copyState(state);
      return { rows: [], rowCount: 0 };
    }
    if (normalized === 'COMMIT') {
      snapshot = null;
      return { rows: [], rowCount: 0 };
    }
    if (normalized === 'ROLLBACK') {
      Object.assign(state, snapshot);
      snapshot = null;
      return { rows: [], rowCount: 0 };
    }
    if (normalized.startsWith('DELETE FROM app.customer_auth_rate_limits')) {
      const cutoff = Number(params[0]) - 7 * 24 * 60 * 60;
      for (const [key, row] of state.rateLimits) {
        if (row.updatedAt < cutoff) state.rateLimits.delete(key);
      }
      return { rows: [], rowCount: 0 };
    }
    if (normalized.startsWith('INSERT INTO app.customer_auth_rate_limits')) {
      const key = `${params[0]}:${params[1]}`;
      if (!state.rateLimits.has(key)) {
        state.rateLimits.set(key, {
          windowStartedAt: Number(params[2]),
          requestCount: 0,
          lastRequestedAt: Number(params[2]) - 24 * 60 * 60,
          updatedAt: Number(params[2]),
        });
      }
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('SELECT window_started_at')) {
      const row = state.rateLimits.get(`${params[0]}:${params[1]}`);
      return {
        rows: row
          ? [
              {
                window_started_at: new Date(row.windowStartedAt * 1000),
                request_count: row.requestCount,
                last_requested_at: new Date(row.lastRequestedAt * 1000),
              },
            ]
          : [],
        rowCount: row ? 1 : 0,
      };
    }
    if (normalized.startsWith('UPDATE app.customer_auth_rate_limits')) {
      const row = state.rateLimits.get(`${params[0]}:${params[1]}`);
      Object.assign(row, {
        windowStartedAt: Number(params[2]),
        requestCount: Number(params[3]),
        lastRequestedAt: Number(params[4]),
        updatedAt: Number(params[4]),
      });
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('DELETE FROM app.customer_otp_challenges')) {
      const cutoff = Number(params[0]) - 24 * 60 * 60;
      for (const [key, row] of state.challenges) {
        if (row.expiresAt < cutoff) state.challenges.delete(key);
      }
      return { rows: [], rowCount: 0 };
    }
    if (normalized.startsWith('INSERT INTO app.customer_otp_challenges')) {
      state.challenges.set(params[1], {
        id: params[0],
        phoneHash: params[1],
        otpHash: params[2],
        expiresAt: Number(params[3]),
        attemptCount: 0,
        providerMessageId: null,
        deliveryAcceptedAt: null,
        consumedAt: null,
        createdAt: Number(params[4]),
      });
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('SELECT id, otp_hash')) {
      const row = state.challenges.get(params[0]);
      return {
        rows: row
          ? [
              {
                id: row.id,
                otp_hash: row.otpHash,
                expires_at: new Date(row.expiresAt * 1000),
                attempt_count: row.attemptCount,
                delivery_accepted_at: row.deliveryAcceptedAt,
                consumed_at: row.consumedAt,
              },
            ]
          : [],
        rowCount: row ? 1 : 0,
      };
    }
    if (normalized.startsWith('UPDATE app.customer_otp_challenges')) {
      const row = [...state.challenges.values()].find(
        (challenge) => challenge.id === params[0],
      );
      if (!row) return { rows: [], rowCount: 0 };
      if (normalized.includes('attempt_count = attempt_count + 1')) {
        row.attemptCount++;
      } else if (normalized.includes('provider_message_id')) {
        row.providerMessageId = params[1];
        row.deliveryAcceptedAt = Number(params[2]);
      } else {
        row.consumedAt = Number(params[1]);
      }
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('SELECT u.id, u.status')) {
      const variants = params[0];
      const rows = [...state.users.values()]
        .filter((user) => user.phone.replace(/\D/g, '') === variants.find(
          (variant) => user.phone.replace(/\D/g, '') === variant,
        ))
        .slice(0, 2)
        .map((user) => ({
          id: user.id,
          status: user.status,
          system_role: user.systemRole,
          customer_user_id: state.customers.has(user.id) ? user.id : null,
        }));
      return { rows, rowCount: rows.length };
    }
    if (normalized.startsWith('INSERT INTO app.users')) {
      const [id, phone] = params;
      state.users.set(id, {
        id,
        phone,
        displayName: 'Customer',
        systemRole: 'customer',
        status: 'active',
      });
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('INSERT INTO app.customers')) {
      state.customers.add(params[0]);
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('SELECT c.user_id')) {
      const customer = state.users.get(params[0]);
      return {
        rows:
          customer && state.customers.has(params[0]) &&
            customer.status === 'active' &&
            customer.systemRole === 'customer'
            ? [{ user_id: params[0] }]
            : [],
        rowCount: 1,
      };
    }
    assert.fail(`Unexpected SQL in customer OTP test: ${normalized}`);
  }

  return {
    state,
    calls,
    async query(sql, params) {
      return query(sql, params);
    },
    async connect() {
      return {
        query,
        release() {},
      };
    },
  };
}

async function startTestServer(app) {
  const server = app.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const address = server.address();
  return {
    url: `http://127.0.0.1:${address.port}`,
    close: () => {
      const closed = new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
      server.closeAllConnections();
      return closed;
    },
  };
}

function createTestServer({
  databasePool = createDatabase(),
  provider = { async send() { return 'wamid.test-message'; } },
  now = () => 2_000_000_000,
  logger = { warn() {} },
} = {}) {
  const app = express();
  app.use(express.json());
  app.use(
    '/api/v1',
    createCustomerOtpAuth({ databasePool, config, provider, now, logger }),
  );
  app.get(
    '/protected',
    createCustomerAuthenticator({ databasePool, config, now }),
    (req, res) => res.json({ customerUserId: req.auth.customerUserId }),
  );
  return { app, databasePool };
}

async function requestOtp(url, phoneNumber = '+919876543210') {
  return fetch(`${url}/api/v1/auth/otp/request`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ phoneNumber }),
  });
}

async function verifyOtp(url, phoneNumber, otp) {
  return fetch(`${url}/api/v1/auth/otp/verify`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ phoneNumber, otp }),
  });
}

function differentOtp(otp) {
  return `${otp[0] === '0' ? '1' : '0'}${otp.slice(1)}`;
}

test('verified OTP creates a customer and returns a valid customer session', async () => {
  let sentOtp;
  const { app, databasePool } = createTestServer({
    provider: {
      async send({ otp }) {
        sentOtp = otp;
        return 'wamid.test-message';
      },
    },
  });
  const running = await startTestServer(app);
  try {
    const request = await requestOtp(running.url);
    const requestBody = await request.json();
    assert.equal(request.status, 202);
    assert.equal(requestBody.data.expiresIn, OTP_LIFETIME_SECONDS);
    assert.equal(requestBody.data.message.includes(sentOtp), false);
    assert.match(sentOtp, /^\d{6}$/);
    const challenge = [...databasePool.state.challenges.values()][0];
    assert.equal(challenge.otpHash.includes(sentOtp), false);
    assert.equal(challenge.deliveryAcceptedAt, 2_000_000_000);

    const verification = await verifyOtp(
      running.url,
      '+919876543210',
      sentOtp,
    );
    const result = await verification.json();
    assert.equal(verification.status, 200);
    assert.equal(result.data.tokenType, 'Bearer');
    assert.equal(result.data.expiresIn, 900);
    assert.equal(databasePool.state.users.size, 1);
    const customerId = [...databasePool.state.customers][0];
    assert.equal(databasePool.state.users.get(customerId).displayName, 'Customer');

    const protectedResponse = await fetch(`${running.url}/protected`, {
      headers: { authorization: `Bearer ${result.data.accessToken}` },
    });
    assert.equal(protectedResponse.status, 200);
    assert.deepEqual(await protectedResponse.json(), {
      customerUserId: customerId,
    });
  } finally {
    await running.close();
  }
});

test('unknown and existing numbers receive the same neutral request response', async () => {
  const existing = createTestServer({
    databasePool: createDatabase({ existingCustomer: true }),
  });
  const newNumber = createTestServer();
  const existingServer = await startTestServer(existing.app);
  const newServer = await startTestServer(newNumber.app);
  try {
    const existingResponse = await requestOtp(existingServer.url);
    const newResponse = await requestOtp(newServer.url);
    assert.equal(existingResponse.status, 202);
    assert.equal(newResponse.status, 202);
    assert.deepEqual(await existingResponse.json(), await newResponse.json());
    assert.equal(existing.databasePool.state.users.size, 1);
    assert.equal(newNumber.databasePool.state.users.size, 0);
  } finally {
    await Promise.all([existingServer.close(), newServer.close()]);
  }
});

test('wrong and expired OTPs cannot create a session', async () => {
  let sentOtp;
  let now = 2_000_000_000;
  const { app, databasePool } = createTestServer({
    now: () => now,
    provider: {
      async send({ otp }) {
        sentOtp = otp;
        return 'wamid.test-message';
      },
    },
  });
  const running = await startTestServer(app);
  try {
    await requestOtp(running.url);
    const wrong = await verifyOtp(
      running.url,
      '+919876543210',
      differentOtp(sentOtp),
    );
    assert.equal(wrong.status, 401);
    assert.equal(
      [...databasePool.state.challenges.values()][0].attemptCount,
      1,
    );
    const correctAfterWrong = await verifyOtp(
      running.url,
      '+919876543210',
      sentOtp,
    );
    assert.equal(correctAfterWrong.status, 200);

    now += 1;
    await requestOtp(running.url, '+919876543211');
    now += OTP_LIFETIME_SECONDS + 1;
    const expired = await verifyOtp(
      running.url,
      '+919876543211',
      sentOtp,
    );
    assert.equal(expired.status, 401);
    assert.equal(databasePool.state.users.size, 1);
  } finally {
    await running.close();
  }
});

test('verification attempts and phone resend requests are rate limited', async () => {
  let sentOtp;
  let now = 2_000_000_000;
  const { app } = createTestServer({
    now: () => now,
    provider: {
      async send({ otp }) {
        sentOtp = otp;
        return 'wamid.test-message';
      },
    },
  });
  const running = await startTestServer(app);
  try {
    await requestOtp(running.url);
    for (let attempt = 0; attempt < 5; attempt++) {
      const response = await verifyOtp(
        running.url,
        '+919876543210',
        differentOtp(sentOtp),
      );
      assert.equal(response.status, 401);
    }
    const exhausted = await verifyOtp(running.url, '+919876543210', sentOtp);
    assert.equal(exhausted.status, 401);

    const cooldown = await requestOtp(running.url);
    assert.equal(cooldown.status, 429);
    assert.ok(Number(cooldown.headers.get('retry-after')) > 0);
    now += 31;
    assert.equal((await requestOtp(running.url)).status, 202);
    now += 31;
    assert.equal((await requestOtp(running.url)).status, 202);
    now += 31;
    assert.equal((await requestOtp(running.url)).status, 429);
  } finally {
    await running.close();
  }
});

test('limits OTP requests from a source IP across different phone numbers', async () => {
  const { app } = createTestServer();
  const running = await startTestServer(app);
  try {
    for (let index = 0; index < 10; index++) {
      const phone = `+${'91'}98765${String(index).padStart(5, '0')}`;
      assert.equal((await requestOtp(running.url, phone)).status, 202);
    }
    const blocked = await requestOtp(running.url, '+919876500010');
    assert.equal(blocked.status, 429);
  } finally {
    await running.close();
  }
});

test('provider failure is surfaced and leaves no verifiable OTP', async () => {
  const warnings = [];
  const { app, databasePool } = createTestServer({
    provider: { async send() { throw new Error('private provider detail'); } },
    logger: { warn(...args) { warnings.push(args); } },
  });
  const running = await startTestServer(app);
  try {
    const failed = await requestOtp(running.url);
    const failureBody = await failed.json();
    assert.equal(failed.status, 503);
    assert.equal(failureBody.error.code, 'OTP_DELIVERY_FAILED');
    assert.equal(JSON.stringify(failureBody).includes('private provider detail'), false);
    assert.equal(JSON.stringify(warnings).includes('+919876543210'), false);
    assert.equal(
      [...databasePool.state.challenges.values()][0].consumedAt,
      2_000_000_000,
    );
    const verification = await verifyOtp(
      running.url,
      '+919876543210',
      '000000',
    );
    assert.equal(verification.status, 401);
    assert.equal(databasePool.state.users.size, 0);
  } finally {
    await running.close();
  }
});

test('production customer auth accepts only production-issued sessions', async () => {
  const productionConfig = {
    ...config,
    nodeEnv: 'production',
    developmentCustomerSessionSecret:
      'development-session-secret-that-is-also-long-enough',
  };
  const databasePool = createDatabase({ existingCustomer: true });
  const app = express();
  app.get(
    '/protected',
    createCustomerAuthenticator({
      databasePool,
      config: productionConfig,
      now: () => 2_000_000_000,
    }),
    (req, res) => res.json({ customerUserId: req.auth.customerUserId }),
  );
  const running = await startTestServer(app);
  try {
    const developmentToken = signCustomerToken(
      existingCustomerId,
      productionConfig.developmentCustomerSessionSecret,
      2_000_000_000,
      DEVELOPMENT_TOKEN_ISSUER,
    );
    const developmentResponse = await fetch(`${running.url}/protected`, {
      headers: { authorization: `Bearer ${developmentToken}` },
    });
    assert.equal(developmentResponse.status, 401);

    const productionToken = signCustomerToken(
      existingCustomerId,
      productionConfig.customerSessionSecret,
      2_000_000_000,
      CUSTOMER_TOKEN_ISSUER,
    );
    const productionResponse = await fetch(`${running.url}/protected`, {
      headers: { authorization: `Bearer ${productionToken}` },
    });
    assert.equal(productionResponse.status, 200);
  } finally {
    await running.close();
  }
});
