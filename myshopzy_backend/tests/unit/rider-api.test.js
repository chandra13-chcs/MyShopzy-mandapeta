const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');
const { DEMO_RIDER_ID } = require('../../src/middleware/mock-rider-auth');

const riderId = '00000000-0000-4000-8000-000000000001';
const orderId = 'd1ca6b39-b9d9-423b-b93b-3e513f232d9a';
const serverNow = new Date('2026-10-15T10:00:00.000Z');
const freshLocationAt = new Date(serverNow).toISOString();

async function startServer(t, options = {}) {
  const server = http.createServer(
    createApp({
      logger: { error() {} },
      now: () => new Date(serverNow),
      ...options,
    }),
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
  locationUpdatedAt = freshLocationAt,
  currentLatitude = 16.87,
  currentLongitude = 81.93,
  activeOrderCount = 0,
} = {}) {
  return {
    async query(sql, params) {
      if (sql.includes('FROM app.riders AS r')) {
        riderQueries?.push(sql);
        return riderExists
          ? {
              rows: [{
                user_id: params[0],
                is_online: isRiderOnline,
                current_latitude: currentLatitude,
                current_longitude: currentLongitude,
                current_location_accuracy: 15,
                current_location_updated_at: locationUpdatedAt,
                active_order_count: activeOrderCount,
              }],
            }
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
              ? {
                  rows: [{
                    user_id: params[0],
                    is_online: isRiderOnline,
                    current_latitude: currentLatitude,
                    current_longitude: currentLongitude,
                    current_location_accuracy: 15,
                    current_location_updated_at: locationUpdatedAt,
                    active_order_count: activeOrderCount,
                  }],
                }
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

test('lists nearby available packed orders without customer address data', async (t) => {
  const queries = [];
  const riderQueries = [];
  const order = {
    orderId,
    pickupArea: 'Mandapeta',
    distanceMeters: 5700,
    deliveryFeeMinor: '5700',
    paymentMethod: 'cod',
    codAmountMinor: '6000',
    pickupLatitude: 16.87,
    pickupLongitude: 81.93,
  };
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      riderQueries,
      queryHandler(sql) {
        queries.push(sql);
        return {
          rows: [
            order,
            {
              ...order,
              orderId: 'd1ca6b39-b9d9-423b-b93b-3e513f232d9b',
              pickupLatitude: 17.1,
            },
          ],
        };
      },
    }),
  });

  const response = await fetch(`${baseUrl}/api/v1/rider/orders/available`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    data: {
      orders: [{
        orderId,
        pickupArea: 'Mandapeta',
        distanceMeters: 5700,
        deliveryFeeMinor: '5700',
        paymentMethod: 'cod',
        codAmountMinor: '6000',
      }],
    },
  });
  const listQuery = queries.find((sql) => sql.includes('app.orders AS o'));
  assert.match(listQuery, /JOIN app\.shops AS s/);
  assert.match(listQuery, /o\.status = 'packed'/);
  assert.match(listQuery, /o\.rider_id IS NULL/);
  assert.match(listQuery, /s\.latitude BETWEEN \$1 AND \$2/);
  assert.match(listQuery, /s\.longitude BETWEEN \$3 AND \$4/);
  assert.doesNotMatch(listQuery, /delivery_address_snapshot|cu\.phone|customerPhone/);
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

test('riders cannot go online or accept orders outside duty hours', async (t) => {
  const outsideNow = () => new Date('2026-10-15T16:30:00.000Z');
  const baseUrl = await startServer(t, {
    now: outsideNow,
    databasePool: transactionPool({
      isRiderOnline: true,
      queryHandler(sql) {
        assert.fail(`Outside-hours rider must not query offers: ${sql}`);
      },
    }),
  });
  const fix = {
    latitude: 16.87,
    longitude: 81.93,
    accuracy: 10,
    capturedAt: outsideNow().toISOString(),
  };

  const offers = await fetch(`${baseUrl}/api/v1/rider/orders/available`);
  assert.equal(offers.status, 200);
  assert.deepEqual((await offers.json()).data.orders, []);

  const accept = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/accept`,
    { method: 'POST' },
  );
  assert.equal(accept.status, 403);
  assert.deepEqual((await accept.json()).error, {
    code: 'RIDER_OUTSIDE_HOURS',
    message: 'Riders may accept new orders only between 7:00 AM and 10:00 PM.',
    opensAt: '07:00',
  });

  const offlineBaseUrl = await startServer(t, {
    now: outsideNow,
    databasePool: transactionPool({ isRiderOnline: false }),
  });
  const online = await fetch(`${offlineBaseUrl}/api/v1/rider/availability`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ isOnline: true, ...fix }),
  });
  assert.equal(online.status, 403);
  assert.deepEqual((await online.json()).error, {
    code: 'RIDER_OUTSIDE_HOURS',
    message: 'Riders may go online only between 7:00 AM and 10:00 PM.',
    opensAt: '07:00',
  });
});

test('stale rider locations receive no offers and cannot accept orders', async (t) => {
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      locationUpdatedAt: new Date(serverNow.getTime() - 121_000).toISOString(),
      queryHandler(sql) {
        assert.fail(`A stale rider must not query offers: ${sql}`);
      },
    }),
  });
  const offers = await fetch(`${baseUrl}/api/v1/rider/orders/available`);
  assert.equal(offers.status, 200);
  assert.deepEqual((await offers.json()).data.orders, []);

  const accept = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/accept`,
    { method: 'POST' },
  );
  assert.equal(accept.status, 403);
  assert.equal((await accept.json()).error.code, 'RIDER_LOCATION_STALE');
});

test('accepts an unassigned packed order transactionally', async (t) => {
  const transactionCalls = [];
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      connectHandler(sql, params) {
        transactionCalls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
        if (sql.includes('SELECT COUNT(*)::int AS count')) {
          return { rows: [{ count: 0 }] };
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
  const assignment = transactionCalls.find(({ sql }) =>
    sql.includes('UPDATE app.orders'),
  ).sql;
  assert.match(assignment, /rider_id IS NULL/);
  assert.match(assignment, /status = 'packed'/);
  assert.equal(
    transactionCalls.filter(({ sql }) => sql.includes('UPDATE app.orders')).length,
    1,
  );
});

test('only one rider can accept an order in concurrent requests', async (t) => {
  const orderState = { riderId: null };
  const otherRiderId = '00000000-0000-4000-8000-000000000002';
  const makeDatabase = () => transactionPool({
    connectHandler(sql, params) {
      if (sql.includes('SELECT COUNT(*)::int AS count')) {
        return { rows: [{ count: 0 }] };
      }
      if (sql.includes('UPDATE app.orders')) {
        if (orderState.riderId !== null) return { rows: [] };
        orderState.riderId = params[1];
        return {
          rows: [{
            orderId,
            status: 'out_for_delivery',
            riderId: params[1],
            updatedAt: freshLocationAt,
          }],
        };
      }
      if (sql.includes('FROM app.orders AS o')) {
        return {
          rows: [{
            orderId,
            status: 'out_for_delivery',
            store: 'Green Basket',
            pickup: { area: 'Mandapeta' },
            drop: { formattedAddress: 'Delivered after acceptance' },
            customerName: 'Customer',
            customerPhone: '+911234567890',
            storePhone: '+911098765432',
            payout: '57.00',
          }],
        };
      }
      return { rows: [] };
    },
  });
  const firstUrl = await startServer(t, {
    databasePool: makeDatabase(),
    authenticateRider(req, res, next) {
      req.auth = { riderUserId: riderId };
      next();
    },
  });
  const secondUrl = await startServer(t, {
    databasePool: makeDatabase(),
    authenticateRider(req, res, next) {
      req.auth = { riderUserId: otherRiderId };
      next();
    },
  });
  const responses = await Promise.all([
    fetch(`${firstUrl}/api/v1/rider/orders/${orderId}/accept`, {
      method: 'POST',
    }),
    fetch(`${secondUrl}/api/v1/rider/orders/${orderId}/accept`, {
      method: 'POST',
    }),
  ]);
  assert.deepEqual(responses.map((response) => response.status).sort(), [200, 409]);
  const loser = responses.find((response) => response.status === 409);
  assert.equal((await loser.json()).error.code, 'ORDER_TAKEN');
});

test("a rider cannot cancel another rider's order", async (t) => {
  let penaltyCalls = 0;
  let updateSql;
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      connectHandler(sql) {
        if (sql.includes('UPDATE app.orders')) {
          updateSql = sql;
          return { rows: [] };
        }
        return { rows: [] };
      },
    }),
    applyRiderCancelPenalty: async () => {
      penaltyCalls += 1;
    },
  });
  const response = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/cancel`,
    {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ reason: 'Cannot reach pickup' }),
    },
  );
  assert.equal(response.status, 404);
  assert.equal((await response.json()).error.code, 'ORDER_NOT_ASSIGNED');
  assert.match(updateSql, /rider_id = \$2/);
  assert.match(updateSql, /rider_stage = 'accepted'/);
  assert.equal(penaltyCalls, 0);
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
    error: { code: 'RIDER_OFFLINE', message: 'Rider is offline' },
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
    error: {
      code: 'RIDER_NOT_ALLOWED',
      message: 'The rider account is not active.',
    },
  });
  assert.deepEqual(orderQueries, []);
});

test('updates status only when the order belongs to the requesting rider', async (t) => {
  let updatedParams;
  let updateSql;
  let earningsInsertSql;
  let earningsInsertParams;
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
              deliveryFeeMinor: '8500',
              currency: 'INR',
            }],
          };
        }
        if (sql.includes('INSERT INTO app.rider_delivery_earnings')) {
          earningsInsertSql = sql;
          earningsInsertParams = params;
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
  assert.equal(earningsInsertParams[2], '8500');

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
              accuracy: 15,
              locationUpdatedAt: freshLocationAt,
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
    body: JSON.stringify({
      latitude: 16.87,
      longitude: 81.93,
      accuracy: 15,
      capturedAt: freshLocationAt,
    }),
  });
  assert.equal(response.status, 200);
  assert.deepEqual((await response.json()).data.location, {
    riderId,
    latitude: 16.87,
    longitude: 81.93,
    accuracy: 15,
    locationUpdatedAt: '2026-10-15T10:00:00.000Z',
    isOnline: true,
    updatedAt: '2026-10-15T10:00:00.000Z',
  });
  assert.deepEqual(updateParams, [
    riderId,
    16.87,
    81.93,
    15,
    true,
    freshLocationAt,
  ]);
  assert.match(updateSql, /is_online = CASE/);
});

test('rejects a location fix older than 60 seconds using server time', async (t) => {
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      queryHandler(sql) {
        assert.fail(`A stale fix must not update rider state: ${sql}`);
      },
    }),
  });
  const response = await fetch(`${baseUrl}/api/v1/rider/location`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      latitude: 16.87,
      longitude: 81.93,
      accuracy: 10,
      capturedAt: new Date(serverNow.getTime() - 61_000).toISOString(),
    }),
  });
  assert.equal(response.status, 422);
  assert.equal((await response.json()).error.code, 'LOCATION_STALE');
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
  assert.deepEqual(updateParams, [riderId, false, null, null, null, null]);

  const onlineResponse = await fetch(`${baseUrl}/api/v1/rider/availability`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ isOnline: true }),
  });
  assert.equal(onlineResponse.status, 422);
  assert.deepEqual(await onlineResponse.json(), {
    error: {
      code: 'LOCATION_REQUIRED',
      message: 'A valid latitude, longitude, accuracy, and capturedAt are required.',
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
              rider_arrived_at: new Date('2026-10-15T09:00:00.000Z'),
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
            rider_arrived_at: new Date('2026-10-15T09:00:00.000Z'),
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

test('only the assigned rider can mark an out-for-delivery order arrived', async (t) => {
  let updates = 0;
  const pool = transactionPool({
    connectHandler(sql) {
      if (sql.includes('SELECT id, rider_id, status, rider_stage')) {
        return {
          rows: [{
            id: orderId,
            rider_id: riderId,
            status: 'out_for_delivery',
            rider_stage: 'out_for_delivery',
          }],
        };
      }
      if (sql.includes('SET rider_arrived_at')) {
        updates += 1;
        return { rows: [{ rider_arrived_at: new Date('2026-10-15T10:00:00Z') }] };
      }
      assert.fail(`Unexpected transaction query: ${sql}`);
    },
  });
  const baseUrl = await startServer(t, {
    databasePool: pool,
    supportPhone: '+91 12345 67890',
    supportEscalationMinutes: 10,
    authenticateRider(req, res, next) {
      req.auth = { riderUserId };
      next();
    },
  });
  const url = `${baseUrl}/api/v1/rider/orders/${orderId}/arrived`;
  const first = await fetch(url, { method: 'PATCH' });
  const firstOrder = (await first.json()).data.order;
  const second = await fetch(url, { method: 'PATCH' });
  const secondOrder = (await second.json()).data.order;

  assert.equal(first.status, 200);
  assert.equal(firstOrder.rider_arrived_at, '2026-10-15T10:00:00.000Z');
  assert.equal(firstOrder.supportAvailableAt, '2026-10-15T10:10:00.000Z');
  assert.equal(firstOrder.supportPhone, '+91 12345 67890');
  assert.equal(second.status, 200);
  assert.equal(secondOrder.rider_arrived_at, firstOrder.rider_arrived_at);
  assert.equal(updates, 2);
});

test('a different rider cannot mark an order arrived', async (t) => {
  const otherRiderId = '00000000-0000-4000-8000-000000000002';
  let updates = 0;
  const baseUrl = await startServer(t, {
    databasePool: transactionPool({
      connectHandler(sql) {
        if (sql.includes('SELECT id, rider_id, status, rider_stage')) {
          return {
            rows: [{
              id: orderId,
              rider_id: otherRiderId,
              status: 'out_for_delivery',
              rider_stage: 'out_for_delivery',
            }],
          };
        }
        if (sql.includes('SET rider_arrived_at')) updates += 1;
        assert.fail(`Unexpected transaction query: ${sql}`);
      },
    }),
    authenticateRider(req, res, next) {
      req.auth = { riderUserId };
      next();
    },
  });
  const response = await fetch(
    `${baseUrl}/api/v1/rider/orders/${orderId}/arrived`,
    { method: 'PATCH' },
  );
  assert.equal(response.status, 404);
  assert.equal((await response.json()).error.code, 'ORDER_NOT_ASSIGNED');
  assert.equal(updates, 0);
});

test('delivery failure enforces the exact support-wait boundary for every customer-fault reason', async (t) => {
  const customerId = '10000000-0000-4000-8000-000000000001';
  let arrivedAt = new Date('2026-10-15T09:50:01.000Z');
  const dueInserts = [];
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
            rider_arrived_at: arrivedAt,
            payment_method: 'cod',
            total_minor: '4500',
            currency: 'INR',
            current_latitude: 16.8,
            current_longitude: 82.0,
          }],
        };
      }
      if (sql.includes('UPDATE app.orders')) {
        return { rows: [{ orderId, status: 'delivery_failed', riderId }] };
      }
      if (sql.includes('INSERT INTO app.customer_ledger_entries')) {
        dueInserts.push(params);
        return { rows: [{ id: params[0] }] };
      }
      assert.fail(`Unexpected transaction query: ${sql}`);
    },
  });
  const baseUrl = await startServer(t, {
    databasePool: pool,
    now: () => new Date('2026-10-15T10:00:00.000Z'),
    authenticateRider(req, res, next) {
      req.auth = { riderUserId };
      next();
    },
  });
  const url = `${baseUrl}/api/v1/rider/orders/${orderId}/delivery-failed`;
  for (const reason of [
    'customer_refused',
    'customer_unreachable',
    'wrong_address_by_customer',
  ]) {
    const waiting = await fetch(url, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ reason, attempts: 1 }),
    });
    const waitingBody = await waiting.json();
    assert.equal(waiting.status, 409);
    assert.equal(waitingBody.error.code, 'SUPPORT_WAIT_NOT_ELAPSED');
    assert.equal(waitingBody.error.remainingSeconds, 1);
    assert.equal(dueInserts.length, 0);
  }

  arrivedAt = new Date('2026-10-15T09:50:00.000Z');
  const elapsed = await fetch(url, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      reason: 'wrong_address_by_customer',
      attempts: 1,
    }),
  });
  assert.equal(elapsed.status, 200);
  assert.equal(dueInserts.length, 1);
});

test('support phone is absent from public endpoints', async (t) => {
  const baseUrl = await startServer(t, {
    supportPhone: '+91 12345 67890',
  });
  const response = await fetch(`${baseUrl}/health`);
  const body = await response.text();
  assert.equal(response.status, 200);
  assert.equal(body.includes('+91 12345 67890'), false);
});
