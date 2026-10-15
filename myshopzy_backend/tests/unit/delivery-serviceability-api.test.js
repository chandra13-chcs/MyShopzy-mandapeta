const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');

async function startServer(t, options = {}) {
  const server = http.createServer(
    createApp({ logger: { error() {} }, ...options }),
  );
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

test('returns the PostgreSQL pincode serviceability contract', async (t) => {
  const queriedPincodes = [];
  const baseUrl = await startServer(t, {
    databasePool: {
      async query(sql, params) {
        queriedPincodes.push(params[0]);
        assert.match(sql, /app\.serviceable_pincodes/);
        return {
          rows: [{ is_deliverable: params[0] === '533308' }],
        };
      },
    },
  });
  const availableResponse = await fetch(
    `${baseUrl}/api/v1/delivery/serviceability`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        latitude: 16.87,
        longitude: 81.93,
        pincode: '533308',
      }),
    },
  );
  assert.equal(availableResponse.status, 200);
  assert.deepEqual(await availableResponse.json(), {
    data: {
      isDeliverable: true,
      message: 'Delivery is available at this location.',
    },
  });

  const unavailableResponse = await fetch(
    `${baseUrl}/api/v1/delivery/serviceability`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        latitude: 16.87,
        longitude: 81.93,
        pincode: '533309',
      }),
    },
  );
  assert.equal(unavailableResponse.status, 200);
  assert.deepEqual(await unavailableResponse.json(), {
    data: {
      isDeliverable: false,
      message: 'Sorry, we do not deliver to this location.',
    },
  });
  assert.deepEqual(queriedPincodes, ['533308', '533309']);
});

test('rejects malformed serviceability requests before database access', async (t) => {
  const baseUrl = await startServer(t, {
    databasePool: {
      query() {
        assert.fail('Serviceability must not query the database.');
      },
    },
  });
  const response = await fetch(
    `${baseUrl}/api/v1/delivery/serviceability`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        latitude: 91,
        longitude: 81.93,
        pincode: '533308',
      }),
    },
  );
  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), {
    error: {
      code: 'INVALID_REQUEST',
      message: 'latitude must be a finite number between -90 and 90.',
    },
  });
});

test('returns a standardized error when the serviceability database is unavailable', async (t) => {
  const baseUrl = await startServer(t);
  const response = await fetch(
    `${baseUrl}/api/v1/delivery/serviceability`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        latitude: 16.87,
        longitude: 81.93,
        pincode: '533308',
      }),
    },
  );
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    error: {
      code: 'DATABASE_UNAVAILABLE',
      message: 'Delivery serviceability is temporarily unavailable.',
    },
  });
});

test('returns a bounded request error for oversized JSON bodies', async (t) => {
  const baseUrl = await startServer(t);
  const response = await fetch(
    `${baseUrl}/api/v1/delivery/serviceability`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        latitude: 16.87,
        longitude: 81.93,
        pincode: '533308',
        padding: 'x'.repeat(17 * 1024),
      }),
    },
  );
  assert.equal(response.status, 413);
  assert.deepEqual(await response.json(), {
    error: {
      code: 'REQUEST_TOO_LARGE',
      message: 'Request body must not exceed 16 KB.',
    },
  });
});

test('fails closed for order placement outside database delivery pincodes', async (t) => {
  const queries = [];
  const baseUrl = await startServer(t, {
    authenticateCustomer(req, res, next) {
      req.auth = { customerUserId: '27dcad4a-f166-4fc8-a224-3d1c099dd459' };
      next();
    },
    databasePool: {
      async query(sql, params) {
        queries.push({ sql, params });
        assert.fail('Order uses a transaction-scoped database client.');
      },
      async connect() {
        return {
          async query(sql, params) {
            queries.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
            return { rows: [], rowCount: 0 };
          },
          release() {},
        };
      },
    },
  });
  const response = await fetch(`${baseUrl}/api/v1/orders`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-cart-token': 'a'.repeat(43),
    },
    body: JSON.stringify({
      deliveryAddress: {
        formattedAddress: 'An unserviceable location',
        pincode: '533309',
      },
    }),
  });
  assert.equal(response.status, 422);
  assert.deepEqual(await response.json(), {
    error: {
      code: 'DELIVERY_UNAVAILABLE',
      message: 'Sorry, we do not deliver to this location.',
    },
  });
  assert.equal(queries.length, 3);
  assert.match(queries[1].sql, /app\.serviceable_pincodes/);
  assert.deepEqual(queries[1].params, ['533309']);
  assert.equal(queries.some((query) => query.sql.startsWith('INSERT INTO app.orders')), false);
});
