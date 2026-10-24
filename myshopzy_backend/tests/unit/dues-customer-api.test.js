const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const { createApp } = require('../../src/app');

const customerId = '27dcad4a-f166-4fc8-a224-3d1c099dd459';
const otherCustomerId = 'a8c2ee15-7b78-4e88-a473-35b95647f419';
const dueId = 'f3caf63d-228d-47b7-9dfd-ecc178c595f2';

async function startServer(t, databasePool) {
  const server = http.createServer(createApp({
    databasePool,
    authenticateCustomer(req, res, next) {
      req.auth = { customerUserId: customerId };
      next();
    },
    logger: { error() {} },
  }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

test('customer dues are scoped to the authenticated customer, not a query parameter', async (t) => {
  const calls = [];
  const entry = {
    id: dueId,
    order_id: 'd1ca6b39-b9d9-423b-b93b-3e513f232d9a',
    reason: 'customer_refused',
    status: 'pending_review',
    amount_minor: '4500',
    disputes: [],
  };
  const client = {
    async query(sql, params = []) {
      const normalized = sql.replace(/\s+/g, ' ').trim();
      calls.push({ sql: normalized, params });
      if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(normalized)) {
        return { rows: [], rowCount: 0 };
      }
      if (normalized.startsWith('SELECT COALESCE(sum(')) {
        return { rows: [{ outstanding_minor: '0' }] };
      }
      if (normalized.startsWith('WITH roots AS')) {
        return { rows: [entry] };
      }
      assert.fail(`Unexpected customer dues query: ${normalized}`);
    },
    release() {},
  };
  const databasePool = { async connect() { return client; } };
  const baseUrl = await startServer(t, databasePool);
  const response = await fetch(
    `${baseUrl}/api/v1/me/dues?customerId=${otherCustomerId}`,
  );
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.data.entries[0].orderId, entry.order_id);
  assert.equal(
    calls.find(({ sql }) => sql.startsWith('WITH roots AS')).params[0],
    customerId,
  );
  assert.notEqual(
    calls.find(({ sql }) => sql.startsWith('WITH roots AS')).params[0],
    otherCustomerId,
  );
});

test("customer cannot dispute another customer's due", async (t) => {
  const calls = [];
  const client = {
    async query(sql, params = []) {
      const normalized = sql.replace(/\s+/g, ' ').trim();
      calls.push({ sql: normalized, params });
      if (normalized === 'BEGIN' || normalized === 'ROLLBACK') {
        return { rows: [], rowCount: 0 };
      }
      if (normalized.includes('WHERE id = $1') && normalized.includes('due_pending_review')) {
        return {
          rows: [{
            id: dueId,
            customer_user_id: otherCustomerId,
            order_id: 'd1ca6b39-b9d9-423b-b93b-3e513f232d9a',
            entry_type: 'due_pending_review',
            amount_minor: '4500',
            currency: 'INR',
            reason: 'customer_refused',
          }],
        };
      }
      assert.fail(`Unexpected customer dues query: ${normalized}`);
    },
    release() {},
  };
  const baseUrl = await startServer(t, { async connect() { return client; } });
  const response = await fetch(`${baseUrl}/api/v1/me/dues/${dueId}/dispute`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ message: 'This delivery was not attempted.' }),
  });
  assert.equal(response.status, 404);
  assert.equal((await response.json()).error.code, 'DUE_NOT_FOUND');
  assert.equal(calls.some(({ sql }) => sql.startsWith('INSERT INTO')), false);
});
