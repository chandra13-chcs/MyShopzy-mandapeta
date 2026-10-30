const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');
const {
  MANDAPETA_BUS_STAND,
} = require('../../src/modules/delivery-serviceability/categories');

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

test('allows preflight requests from the configured local customer web app', async (t) => {
  const baseUrl = await startServer(t);
  const response = await fetch(`${baseUrl}/api/v1/me/parcels`, {
    method: 'OPTIONS',
    headers: {
      origin: 'http://127.0.0.1:7357',
      'access-control-request-method': 'POST',
      'access-control-request-headers': 'authorization,content-type',
    },
  });
  assert.equal(response.status, 204);
  assert.equal(
    response.headers.get('access-control-allow-origin'),
    'http://127.0.0.1:7357',
  );
  assert.match(response.headers.get('access-control-allow-methods'), /POST/);
  assert.match(response.headers.get('access-control-allow-headers'), /Authorization/);
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

test('blocks grocery order placement outside its fixed-origin category limit', async (t) => {
  const queries = [];
  const destination = { latitude: 16.87, longitude: 81.93 };
  const baseUrl = await startServer(t, {
    authenticateCustomer(req, res, next) {
      req.auth = { customerUserId: '27dcad4a-f166-4fc8-a224-3d1c099dd459' };
      next();
    },
    deliveryDistanceClient: {
      async getRoadDistanceMetres(origin, routedDestination) {
        assert.deepEqual(origin, MANDAPETA_BUS_STAND);
        assert.deepEqual(routedDestination, destination);
        return 10001;
      },
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
            if (sql.includes('SELECT user_id FROM app.customers')) {
              return { rows: [{ user_id: params[0] }], rowCount: 1 };
            }
            if (sql.includes('outstanding_minor')) {
              return {
                rows: [{ outstanding_minor: '0' }],
                rowCount: 1,
              };
            }
            if (sql.includes('FROM app.customers AS c')) {
              return { rows: [{ user_id: params[0] }], rowCount: 1 };
            }
            if (sql.includes('FROM app.customer_carts')) {
              return {
                rows: [{
                  id: 'cart-id',
                  shop_id: 'shop-id',
                  partner_id: 'partner-id',
                }],
                rowCount: 1,
              };
            }
            if (sql.includes('FROM app.customer_cart_items')) {
              return {
                rows: [{
                  product_id: 'product-id',
                  variant_id: 'variant-id',
                  quantity: 1,
                  shop_id: 'shop-id',
                  partner_id: 'partner-id',
                  name: 'Test grocery',
                  currency: 'INR',
                  product_is_available: true,
                  product_status: 'active',
                  variant_label: 'One',
                  variant_unit: 'each',
                  variant_quantity: '1',
                  variant_sku: 'TEST-1',
                  price_minor: '1000',
                  variant_stock: 10,
                  variant_is_available: true,
                  shop_status: 'active',
                  shop_latitude: 16.87,
                  shop_longitude: 81.93,
                  operating_details: null,
                  timezone: 'Asia/Kolkata',
                  partner_status: 'approved',
                  partner_type: 'local_store',
                  partner_commission_bps_override: null,
                  category_code: null,
                  category_commission_bps_override: null,
                }],
                rowCount: 1,
              };
            }
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
        ...destination,
      },
    }),
  });
  assert.equal(response.status, 422);
  assert.deepEqual(await response.json(), {
    error: {
      code: 'OUTSIDE_DELIVERY_RANGE',
      message: 'Sorry, this service is available only within 10 km of Mandapeta Bus Stand.',
      details: {
        category: 'grocery',
        distanceMeters: 10001,
        maximumDistanceMeters: 10000,
      },
    },
  });
  assert.equal(queries.some((query) => query.sql.includes('app.serviceable_pincodes')), false);
  assert.equal(queries.some((query) => query.sql.startsWith('INSERT INTO app.orders')), false);
});
