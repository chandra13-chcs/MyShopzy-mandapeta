const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');

const adminId = 'a8c2ee15-7b78-4e88-a473-35b95647f419';
const orderId = 'd1ca6b39-b9d9-423b-b93b-3e513f232d9a';
const customerId = '10000000-0000-4000-8000-000000000001';

function createPool({
  paymentMethod = 'cod',
  existingDue = false,
  initialResolution = null,
} = {}) {
  const calls = [];
  const dues = existingDue ? [{ id: 'existing-due' }] : [];
  const resolutions = initialResolution ? [initialResolution] : [];
  const pool = {
    dues,
    resolutions,
    calls,
    async connect() {
      return {
        async query(sql, params = []) {
          const query = sql.replace(/\s+/g, ' ').trim();
          calls.push({ query, params });
          if (query === 'BEGIN' || query === 'COMMIT' || query === 'ROLLBACK') {
            return { rows: [] };
          }
          if (query.startsWith('SELECT COUNT(*)::int AS total')) {
            return { rows: [{ total: 1 }] };
          }
          if (query.startsWith('WITH page AS')) return { rows: [] };
          if (query.startsWith('SELECT o.id AS "orderId"')) {
            return {
              rows: [{
                orderId,
                customerPhone: '+91 12345 67890',
                riderName: 'Rider One',
                minutesWaiting: 12,
                due: null,
              }],
            };
          }
          if (query.startsWith('SELECT o.id, o.customer_user_id')) {
            return {
              rows: [{
                id: orderId,
                customer_user_id: customerId,
                rider_id: '00000000-0000-4000-8000-000000000001',
                status: 'out_for_delivery',
                payment_method: paymentMethod,
                total_minor: '9000',
                currency: 'INR',
                rider_arrived_at: new Date('2026-10-15T09:00:00Z'),
                support_wait_elapsed: true,
                remaining_seconds: 0,
              }],
            };
          }
          if (query.includes('FROM app.order_support_resolutions')) {
            return { rows: resolutions.map((row) => ({ order_id: row.order_id })) };
          }
          if (query.startsWith('UPDATE app.orders')) return { rows: [] };
          if (
            query.includes('FROM app.customer_ledger_entries') &&
            query.includes('entry_type =')
          ) {
            return { rows: dues };
          }
          if (query.startsWith('INSERT INTO app.customer_ledger_entries')) {
            const due = { id: params[0], amount_minor: params[3] };
            dues.push(due);
            return { rows: [due] };
          }
          if (query.startsWith('INSERT INTO app.order_support_resolutions')) {
            const resolution = {
              order_id: params[0],
              outcome: params[1],
              support_reference: params[2],
            };
            resolutions.push(resolution);
            return { rows: [resolution] };
          }
          assert.fail(`Unexpected transaction query: ${query}`);
        },
        release() {},
      };
    },
  };
  return pool;
}

function authenticateAdmin(req, res, next) {
  if (req.get('authorization') === 'Bearer admin') {
    req.auth = { adminUserId: adminId };
  }
  next();
}

async function startServer(t, databasePool) {
  const server = http.createServer(
    createApp({ databasePool, authenticateAdmin }),
  );
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));
  return `http://127.0.0.1:${server.address().port}`;
}

function resolveRequest(baseUrl, outcome) {
  return fetch(`${baseUrl}/api/v1/admin/support/escalations/${orderId}/resolve`, {
    method: 'POST',
    headers: {
      authorization: 'Bearer admin',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      supportReference: 'SUP-123',
      outcome,
      note: 'Call completed',
    }),
  });
}

test('support escalation endpoints reject requests without admin authentication', async (t) => {
  const pool = createPool();
  const baseUrl = await startServer(t, pool);
  const response = await fetch(`${baseUrl}/api/v1/admin/support/escalations`);
  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, 'AUTHENTICATION_REQUIRED');
  assert.equal(pool.calls.length, 0);
});

test('admin escalation queue is paged and exposes customer, rider, wait, and due details', async (t) => {
  const pool = createPool();
  const baseUrl = await startServer(t, pool);
  const response = await fetch(
    `${baseUrl}/api/v1/admin/support/escalations?limit=5&offset=10`,
    { headers: { authorization: 'Bearer admin' } },
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.deepEqual(body.data.escalations[0], {
    orderId,
    customerPhone: '+91 12345 67890',
    riderName: 'Rider One',
    minutesWaiting: 12,
    due: null,
  });
  assert.deepEqual(body.meta.pagination, { limit: 5, offset: 10, total: 1 });
  const queueUpdate = pool.calls.find(({ query }) =>
    query.startsWith('WITH page AS'),
  );
  assert.match(queueUpdate.query, /support_escalated_at = COALESCE/);
  assert.deepEqual(queueUpdate.params, [10, 5, 10]);
});

test('resolving one COD escalation twice creates exactly one due from order total', async (t) => {
  const pool = createPool();
  const baseUrl = await startServer(t, pool);

  const first = await resolveRequest(baseUrl, 'customer_unreachable');
  assert.equal(first.status, 200);
  assert.equal(pool.dues.length, 1);
  assert.equal(pool.dues[0].amount_minor, '9000');
  const dueInsert = pool.calls.find(({ query }) =>
    query.startsWith('INSERT INTO app.customer_ledger_entries'),
  );
  assert.equal(dueInsert.params[3], '9000');
  assert.equal(dueInsert.params[8], `admin:${adminId}`);

  const second = await resolveRequest(baseUrl, 'customer_unreachable');
  assert.equal(second.status, 409);
  assert.equal((await second.json()).error.code, 'SUPPORT_ALREADY_RESOLVED');
  assert.equal(pool.dues.length, 1);
});

test('prepaid support resolutions never create a due', async (t) => {
  const pool = createPool({ paymentMethod: 'prepaid' });
  const baseUrl = await startServer(t, pool);
  const response = await resolveRequest(baseUrl, 'customer_refused');

  assert.equal(response.status, 200);
  assert.equal(pool.dues.length, 0);
  assert.equal(
    pool.calls.some(({ query }) =>
      query.startsWith('INSERT INTO app.customer_ledger_entries'),
    ),
    false,
  );
});

test('customer reached resolves the escalation without creating a due', async (t) => {
  const pool = createPool();
  const baseUrl = await startServer(t, pool);
  const response = await resolveRequest(baseUrl, 'customer_reached');

  assert.equal(response.status, 200);
  assert.equal(pool.resolutions.length, 1);
  assert.equal(pool.dues.length, 0);
});
