const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');
const { DEMO_RIDER_ID } = require('../../src/middleware/mock-rider-auth');

const riderId = '00000000-0000-4000-8000-000000000001';
const orderId = 'd1ca6b39-b9d9-423b-b93b-3e513f232d9a';

async function startServer(t, options = {}) {
  const server = http.createServer(
    createApp({ logger: { error() {} }, ...options }),
  );
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

function transactionPool({
  queryHandler,
  connectHandler,
  isRiderOnline = true,
  riderExists = true,
  riderQueries = null,
} = {}) {
  return {
    async query(sql, params) {
      if (sql.includes('FROM app.riders AS r')) {
        riderQueries?.push(sql);
        return riderExists
          ? { rows: [{ user_id: params[0], is_online: isRiderOnline }] }
          : { rows: [] };
      }
      if (queryHandler) return queryHandler(sql, params);
      assert.fail(`Unexpected pool query: ${sql}`);
    },
    async connect() {
      const calls = [];
      return {
        calls,
        async query(sql, params) {
          calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
          if (sql.includes('FROM app.riders AS r')) {
            return riderExists
              ? { rows: [{ user_id: params[0], is_online: isRiderOnline }] }
              : { rows: [] };
          }
          if (connectHandler) return connectHandler(sql, params, calls);
          assert.fail(`Unexpected transaction query: ${sql}`);
        },
        release() {
          calls.push({ sql: 'RELEASE' });
        },
      };
    },
  };
}

test('lists available packed orders with shop and delivery details', async (t) => {
  const queries = [];
  const riderQueries = [];
  const order = {
    orderId,
    status: 'getting_packed',
    shopId: '20000000-0000-4000-8000-000000000001',
    store: 'Green Basket',
    pickup: { locality: 'Mandapeta' },
    drop: { formattedAddress: '12 Market Road' },
    currency: 'INR',
    itemsSubtotalMinor: '6000',
    deliveryFeeMinor: '0',
    totalMinor: '6000',
    placedAt: '2026-10-15T10:00:00.000Z',
  };
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      riderQueries,
      queryHandler(sql) {
        queries.push(sql);
        return { rows: [order] };
      },
    }),
  });

  const response = await fetch(`${baseUrl}/api/v1/rider/orders/available`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { data: { orders: [order] } });
  const listQuery = queries.find((sql) => sql.includes('app.orders AS o'));
  assert.match(listQuery, /JOIN app\.shops AS s/);
  assert.match(listQuery, /o\.status = 'getting_packed'/);
  assert.match(listQuery, /o\.rider_id IS NULL/);
  assert.match(listQuery, /online_rider\.is_online = true/);
  assert.match(riderQueries[0], /r\.is_online/);
});

test('offline and missing riders cannot poll for available orders', async (t) => {
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({ isRiderOnline: false }),
  });

  const defaultResponse = await fetch(`${baseUrl}/api/v1/rider/orders/available`);
  assert.equal(defaultResponse.status, 403);
  assert.deepEqual(await defaultResponse.json(), {
    error: { code: 'RIDER_OFFLINE', message: 'Rider is offline.' },
  });

  const invalidResponse = await fetch(
    `${baseUrl}/api/v1/rider/orders/available`,
    { headers: { 'X-Rider-Id': 'not-a-uuid' } },
  );
  assert.equal(invalidResponse.status, 400);
  assert.deepEqual(await invalidResponse.json(), {
    error: {
      code: 'INVALID_RIDER_ID',
      message: 'X-Rider-Id must be a valid UUID.',
    },
  });

  const missingRiderServer = await startServer(t, {
    databasePool: transactionPool({ riderExists: false }),
  });
  const missingRiderResponse = await fetch(
    `${missingRiderServer}/api/v1/rider/orders/available`,
  );
  assert.equal(missingRiderResponse.status, 403);
  assert.deepEqual(await missingRiderResponse.json(), {
    error: {
      code: 'RIDER_NOT_ALLOWED',
      message: 'The rider account is not active.',
    },
  });
});

test('accepts an unassigned packed order transactionally', async (t) => {
  const transactionCalls = [];
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      connectHandler(sql, params) {
        transactionCalls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
        if (sql.includes('SELECT id, status, rider_id')) {
          return {
            rows: [{ id: orderId, status: 'getting_packed', rider_id: null }],
          };
        }
        if (sql.includes('UPDATE app.orders')) {
          return {
            rows: [{
              orderId,
              status: 'out_for_delivery',
              riderId,
              updatedAt: '2026-10-15T10:00:00.000Z',
            }],
          };
        }
        if (sql.includes('FROM app.orders AS o')) {
          return {
            rows: [{
              orderId,
              status: 'out_for_delivery',
              store: 'Green Basket',
              pickup: { latitude: 16.87, longitude: 81.93 },
              drop: { latitude: 16.88, longitude: 81.94 },
              customerName: 'Rider Customer',
              customerPhone: '+911234567890',
              storePhone: '+911098765432',
              payout: '85.00',
              pickupLatitude: '16.87',
              pickupLongitude: '81.93',
              dropLatitude: '16.88',
              dropLongitude: '81.94',
            }],
          };
        }
        return { rows: [] };
      },
    }),
  });

  const response = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/accept`,
    { method: 'POST' },
  );
  assert.equal(response.status, 200);
  const acceptedOrder = (await response.json()).data.order;
  assert.deepEqual(acceptedOrder, {
    orderId,
    status: 'out_for_delivery',
    riderId,
    updatedAt: '2026-10-15T10:00:00.000Z',
    store: 'Green Basket',
    pickup: { latitude: 16.87, longitude: 81.93 },
    drop: { latitude: 16.88, longitude: 81.94 },
    customerName: 'Rider Customer',
    customerPhone: '+911234567890',
    storePhone: '+911098765432',
    payout: '85.00',
    pickupLatitude: '16.87',
    pickupLongitude: '81.93',
    dropLatitude: '16.88',
    dropLongitude: '81.94',
  });
  const detailsQuery = transactionCalls.find(({ sql }) =>
    sql.includes('FROM app.orders AS o'),
  ).sql;
  assert.match(detailsQuery, /JOIN app\.partners AS p/);
  assert.match(detailsQuery, /p\.contact_phone AS "storePhone"/);
  assert.deepEqual(
    transactionCalls.map(({ sql }) => sql).filter((sql) =>
      ['BEGIN', 'COMMIT', 'ROLLBACK'].includes(sql),
    ),
    ['BEGIN', 'COMMIT'],
  );
  assert.match(
    transactionCalls.find(({ sql }) => sql.includes('UPDATE app.orders')).sql,
    /rider_id IS NULL/,
  );
});

test('rejects order acceptance and does not inspect or update orders while offline', async (t) => {
  const orderQueries = [];
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      isRiderOnline: false,
      connectHandler(sql) {
        if (sql.includes('app.orders')) {
          orderQueries.push(sql);
          assert.fail('An offline rider must not query or update orders.');
        }
        return { rows: [] };
      },
    }),
  });

  const response = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/accept`,
    { method: 'POST' },
  );
  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), {
    success: false,
    message: 'Rider is offline',
  });
  assert.deepEqual(orderQueries, []);
});

test('rejects order acceptance when the rider does not exist', async (t) => {
  const orderQueries = [];
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      riderExists: false,
      connectHandler(sql) {
        if (sql.includes('app.orders')) {
          orderQueries.push(sql);
          assert.fail('A missing rider must not query or update orders.');
        }
        return { rows: [] };
      },
    }),
  });

  const response = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/accept`,
    { method: 'POST' },
  );
  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), {
    success: false,
    message: 'Rider is offline',
  });
  assert.deepEqual(orderQueries, []);
});

test('updates status only when the order belongs to the requesting rider', async (t) => {
  let updatedParams;
  let updateSql;
  let earningsInsertSql;
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      connectHandler(sql, params) {
        if (sql.includes('UPDATE app.orders')) {
          updatedParams = params;
          updateSql = sql;
          return {
            rows: [{
              orderId,
              status: 'delivered',
              riderId,
              updatedAt: '2026-10-15T10:00:00.000Z',
              payoutMinor: '8500',
              currency: 'INR',
            }],
          };
        }
        if (sql.includes('INSERT INTO app.rider_delivery_earnings')) {
          earningsInsertSql = sql;
        }
        return { rows: [] };
      },
    }),
  });

  const response = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/status`,
    {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ status: 'delivered' }),
    },
  );
  assert.equal(response.status, 200);
  assert.deepEqual(updatedParams, [
    orderId,
    riderId,
    'delivered',
    'out_for_delivery',
  ]);
  const replayResponse = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/status`,
    {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ status: 'delivered' }),
    },
  );
  assert.equal(replayResponse.status, 200);
  assert.match(updateSql, /rider_stage IN \(\$3, \$4\)/);
  assert.match(earningsInsertSql, /ON CONFLICT \(order_id\) DO NOTHING/);

  const invalidResponse = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/status`,
    {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ status: 'cancelled' }),
    },
  );
  assert.equal(invalidResponse.status, 400);
});

test('updates live location and marks the rider online', async (t) => {
  let updateSql;
  let updateParams;
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      connectHandler(sql, params) {
        if (sql.includes('UPDATE app.riders AS r')) {
          updateSql = sql;
          updateParams = params;
          return {
            rows: [{
              riderId,
              latitude: 16.87,
              longitude: 81.93,
              isOnline: true,
              updatedAt: '2026-10-15T10:00:00.000Z',
            }],
          };
        }
        return { rows: [] };
      },
    }),
  });

  const response = await fetch(`${baseUrl}/api/v1/rider/location`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ latitude: 16.87, longitude: 81.93 }),
  });
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).data.location, {
    riderId,
    latitude: 16.87,
    longitude: 81.93,
    isOnline: true,
    updatedAt: '2026-10-15T10:00:00.000Z',
  });
  assert.deepEqual(updateParams, [riderId, 16.87, 81.93]);
  assert.match(updateSql, /is_online = true/);
});

test('offline riders can clear duty, but cannot enable it without a location fix', async (t) => {
  let updateParams;
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      queryHandler(sql, params) {
        if (sql.includes('UPDATE app.riders AS r')) {
          updateParams = params;
          return { rows: [{ isOnline: false }] };
        }
        assert.fail(`Unexpected pool query: ${sql}`);
      },
    }),
  });

  const offlineResponse = await fetch(`${baseUrl}/api/v1/rider/availability`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ isOnline: false }),
  });
  assert.equal(offlineResponse.status, 200);
  assert.deepEqual((await offlineResponse.json()).data.availability, {
    isOnline: false,
  });
  assert.deepEqual(updateParams, [riderId]);

  const onlineResponse = await fetch(`${baseUrl}/api/v1/rider/availability`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ isOnline: true }),
  });
  assert.equal(onlineResponse.status, 409);
  assert.deepEqual(await onlineResponse.json(), {
    error: {
      code: 'LOCATION_REQUIRED',
      message: 'Share a valid location to go online.',
    },
  });
});

test('returns the rider settlement summary from completed deliveries', async (t) => {
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      queryHandler(sql) {
        if (sql.includes('FROM app.rider_delivery_earnings')) {
          return {
            rows: [{
              todayPayoutMinor: '12500',
              todayDeliveries: 3,
              lifetimePayoutMinor: '90000',
              lifetimeDeliveries: 20,
            }],
          };
        }
        assert.fail(`Unexpected pool query: ${sql}`);
      },
    }),
  });

  const response = await fetch(`${baseUrl}/api/v1/rider/earnings/summary`);
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).data.summary, {
    todayPayoutMinor: '12500',
    todayDeliveries: 3,
    lifetimePayoutMinor: '90000',
    lifetimeDeliveries: 20,
  });
});

test('requires injected rider authentication in production', async (t) => {
  const baseUrl = await startServer(t, {
    nodeEnv: 'production',
  });
  const response = await fetch(`${baseUrl}/api/v1/rider/orders/available`);
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), {
    error: {
      code: 'AUTHENTICATION_REQUIRED',
      message: 'Rider authentication is required.',
    },
  });

  const unrelatedResponse = await fetch(`${baseUrl}/api/v1/not-a-rider-route`);
  assert.equal(unrelatedResponse.status, 404);
});

test("a rider cannot mark another rider's order as delivery failed", async (t) => {
  const otherRiderId = '00000000-0000-4000-8000-000000000002';
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      connectHandler(sql) {
        if (sql.includes('FROM app.orders AS o')) {
          return {
            rows: [{
              id: orderId,
              customer_user_id: '10000000-0000-4000-8000-000000000001',
              rider_id: otherRiderId,
              status: 'out_for_delivery',
              rider_stage: 'out_for_delivery',
              payment_method: 'cod',
              total_minor: '4500',
              currency: 'INR',
              current_latitude: 16.8,
              current_longitude: 82.0,
            }],
          };
        }
        assert.fail(`Unexpected transaction query: ${sql}`);
      },
    }),
    authenticateRider(req, res, next) {
      req.auth = { riderUserId };
      next();
    },
  });
  const response = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/delivery-failed`,
    {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        reason: 'customer_refused',
        attempts: 1,
      }),
    },
  );
  assert.equal(response.status, 404);
  assert.equal((await response.json()).error.code, 'ORDER_NOT_ASSIGNED');
});

test('delivery failure ignores client amounts, records COD order total, and skips prepaid dues', async (t) => {
  const customerId = '10000000-0000-4000-8000-000000000001';
  const dueInserts = [];
  let paymentMethod = 'cod';
  const pool = transactionPool({
    connectHandler(sql, params) {
      if (sql.includes('FROM app.orders AS o')) {
        return {
          rows: [{
            id: orderId,
            customer_user_id: customerId,
            rider_id: riderId,
            status: 'out_for_delivery',
            rider_stage: 'out_for_delivery',
            payment_method: paymentMethod,
            total_minor: '4500',
            currency: 'INR',
            current_latitude: 16.8,
            current_longitude: 82.0,
          }],
        };
      }
      if (sql.includes('UPDATE app.orders')) {
        return {
          rows: [{
            orderId,
            status: 'delivery_failed',
            riderId,
            reason: params[1],
          }],
        };
      }
      if (sql.includes('INSERT INTO app.customer_ledger_entries')) {
        dueInserts.push({ sql, params });
        return { rows: [{ id: params[0] }] };
      }
      assert.fail(`Unexpected transaction query: ${sql}`);
    },
  });
  const baseUrl = await startServer(t, {
    databasePool: pool,
    authenticateRider(req, res, next) {
      req.auth = { riderUserId };
      next();
    },
  });
  const url = `${baseUrl}/api/v1/rider/orders/${orderId}/delivery-failed`;
  const request = (body) => fetch(url, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

  const tampered = await request({
    reason: 'customer_refused',
    attempts: 1,
    amountMinor: 1,
  });
  assert.equal(tampered.status, 400);
  assert.equal(dueInserts.length, 0);

  const codFailure = await request({
    reason: 'customer_refused',
    attempts: 1,
    note: 'Customer declined delivery',
  });
  assert.equal(codFailure.status, 200);
  assert.equal(dueInserts.length, 1);
  assert.equal(dueInserts[0].params[3], '4500');
  assert.equal(dueInserts[0].params[8], `rider:${riderId}`);
  assert.deepEqual(JSON.parse(dueInserts[0].params[7]), {
    attempts: 1,
    latitude: 16.8,
    longitude: 82.0,
  });

  paymentMethod = 'prepaid';
  const prepaidFailure = await request({
    reason: 'customer_unreachable',
    attempts: 2,
  });
  assert.equal(prepaidFailure.status, 200);
  assert.equal(dueInserts.length, 1);
});
