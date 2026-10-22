const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const { createApp } = require('../../src/app');

const adminId = 'a8c2ee15-7b78-4e88-a473-35b95647f419';
const resources = [
  ['/api/v1/admin/orders', 'orders'],
  ['/api/v1/admin/customers', 'customers'],
  ['/api/v1/admin/partners', 'partners'],
  ['/api/v1/admin/catalog/products', 'products'],
];

function createPool(queryHandler = async () => ({ rows: [] })) {
  const calls = [];
  return {
    calls,
    async query(sql, params) {
      calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      return queryHandler(sql, params, calls.length);
    },
  };
}

async function startServer(t, databasePool, { authenticateAdmin } = {}) {
  const server = http.createServer(createApp({ databasePool, authenticateAdmin }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));
  return `http://127.0.0.1:${server.address().port}`;
}

function testAuthenticator(req, res, next) {
  if (req.get('authorization') === 'Bearer test-admin') {
    req.auth = { adminUserId: adminId };
  }
  next();
}

async function request(baseUrl, path, options = {}) {
  return fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      ...(options.headers ?? {}),
    },
  });
}

test('keeps admin resources inaccessible without trusted admin authentication', async (t) => {
  const pool = createPool();
  const baseUrl = await startServer(t, pool, { authenticateAdmin: testAuthenticator });

  for (const [path] of resources) {
    const response = await request(baseUrl, path);
    const body = await response.json();
    assert.equal(response.status, 401);
    assert.equal(body.error.code, 'AUTHENTICATION_REQUIRED');
    assert.equal(body.meta.requestId, response.headers.get('x-request-id'));
    assert.match(body.meta.requestId, /^[0-9a-f-]{36}$/i);
  }
  assert.equal(pool.calls.length, 0);
});

test('exposes category sales and commission totals only to authenticated admins', async (t) => {
  const path = '/api/v1/admin/catalog/category-commission-totals';
  const expected = [{
    categoryCode: 'frozen_foods',
    currency: 'INR',
    itemSalesMinor: '50000',
    commissionMinor: '5000',
  }];
  const pool = createPool(() => ({ rows: expected }));
  const baseUrl = await startServer(t, pool, { authenticateAdmin: testAuthenticator });

  const unauthorized = await request(baseUrl, path);
  assert.equal(unauthorized.status, 401);
  assert.equal(pool.calls.length, 0);

  const response = await request(baseUrl, path, {
    headers: { authorization: '******' },
  });
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).data, expected);
  assert.equal(pool.calls.length, 1);
  assert.match(pool.calls[0].sql, /GROUP BY category\.category_code/);
});

test('lists all four resources through the existing queries and response adapter', async (t) => {
  const pool = createPool((_sql, _params, call) => call % 2
    ? { rows: [{ total: '1' }] }
    : { rows: [{ id: `record-${call}` }] });
  const baseUrl = await startServer(t, pool, { authenticateAdmin: testAuthenticator });

  for (const [path] of resources) {
    const response = await request(baseUrl, path, {
      headers: { authorization: 'Bearer test-admin', 'x-request-id': 'admin-list-test' },
    });
    const body = await response.json();
    assert.equal(response.status, 200);
    assert.deepEqual(body.data, [{ id: `record-${pool.calls.length}` }]);
    assert.deepEqual(body.meta.pagination, { limit: 25, offset: 0, total: 1 });
    assert.equal(body.meta.requestId, 'admin-list-test');
    assert.equal(response.headers.get('x-request-id'), 'admin-list-test');
  }
  assert.equal(pool.calls.length, 8);
  assert.ok(pool.calls.every(({ params }) => Array.isArray(params)));
});

test('validates list filters before querying and sanitizes database failures', async (t) => {
  const pool = createPool((_sql, _params, call) => {
    if (call === 1) throw Object.assign(
      new Error('private connection string and SQL diagnostic'),
      { code: '08006' },
    );
    return { rows: [] };
  });
  const baseUrl = await startServer(t, pool, { authenticateAdmin: testAuthenticator });
  const headers = { authorization: 'Bearer test-admin' };

  const invalid = await request(baseUrl, '/api/v1/admin/orders?limit=1000', { headers });
  const invalidBody = await invalid.json();
  assert.equal(invalid.status, 400);
  assert.equal(invalidBody.error.code, 'INVALID_REQUEST');
  assert.equal(invalidBody.meta.requestId, invalid.headers.get('x-request-id'));
  assert.equal(pool.calls.length, 0);

  const unavailable = await request(baseUrl, '/api/v1/admin/orders', { headers });
  const unavailableBody = await unavailable.json();
  assert.equal(unavailable.status, 503);
  assert.equal(unavailableBody.error.code, 'DATABASE_UNAVAILABLE');
  assert.equal(unavailableBody.meta.requestId, unavailable.headers.get('x-request-id'));
  assert.doesNotMatch(JSON.stringify(unavailableBody), /private|connection string|diagnostic/);
});

test('validates detail IDs and returns a request-ID-bearing not-found response', async (t) => {
  const pool = createPool();
  const baseUrl = await startServer(t, pool, { authenticateAdmin: testAuthenticator });
  const headers = { authorization: 'Bearer test-admin' };

  const invalid = await request(baseUrl, '/api/v1/admin/orders/not-a-uuid', { headers });
  assert.equal(invalid.status, 400);
  assert.equal((await invalid.json()).error.code, 'INVALID_REQUEST');
  assert.equal(pool.calls.length, 0);

  const missing = await request(
    baseUrl,
    '/api/v1/admin/orders/a8c2ee15-7b78-4e88-a473-35b95647f419',
    { headers },
  );
  const missingBody = await missing.json();
  assert.equal(missing.status, 404);
  assert.equal(missingBody.error.code, 'NOT_FOUND');
  assert.equal(missingBody.meta.requestId, missing.headers.get('x-request-id'));
  assert.deepEqual(pool.calls[0].params, ['a8c2ee15-7b78-4e88-a473-35b95647f419']);
});
