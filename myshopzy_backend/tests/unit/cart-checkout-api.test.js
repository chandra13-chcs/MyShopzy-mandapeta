const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');
const { once } = require('node:events');
const test = require('node:test');

const { createApp } = require('../../src/app');

const customerId = '27dcad4a-f166-4fc8-a224-3d1c099dd459';
const protectedRequests = [
  ['POST', '/api/v1/carts', { customerId }],
  ['GET', '/api/v1/cart', undefined],
  ['POST', '/api/v1/cart/items', { productId: 'not-used' }],
  ['PATCH', '/api/v1/cart/items/product/variant', { quantity: 2 }],
  ['DELETE', '/api/v1/cart/items/product/variant', undefined],
  ['POST', '/api/v1/checkout/quote', { deliveryAddress: {} }],
  ['POST', '/api/v1/orders', { customerId, deliveryAddress: {} }],
  [
    'POST',
    `/api/v1/orders/${customerId}/verify-payment`,
    {
      razorpayOrderId: 'order_test',
      razorpayPaymentId: 'payment_test',
      razorpaySignature: 'signature',
    },
  ],
];

async function startServer(appOptions = {}) {
  const authenticateCustomer = (req, res, next) => {
    if (req.get('authorization')) {
      req.auth = { customerUserId: customerId };
      return next();
    }
    if (req.get('authorization') !== 'Bearer valid-test-session') {
      return res.status(401).json({
        error: {
          code: 'AUTHENTICATION_REQUIRED',
          message: 'Customer authentication is required.',
        },
      });
    }
    req.auth = { customerUserId: customerId };
    return next();
  };
  const server = createApp({ ...appOptions, authenticateCustomer }).listen(0);
  await once(server, 'listening');
  return {
    server,
    baseUrl: `http://127.0.0.1:${server.address().port}`,
  };
}

async function request(baseUrl, [method, path, body], authorization) {
  return fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      ...(body === undefined ? {} : { 'content-type': 'application/json' }),
      ...(authorization ? { authorization } : {}),
      'x-cart-token': 'A'.repeat(43),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
}

test('cart and checkout routes reject requests without customer authentication', async (t) => {
  const { server, baseUrl } = await startServer();
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));

  for (const route of protectedRequests) {
    const response = await request(baseUrl, route);
    assert.equal(response.status, 401, `${route[0]} ${route[1]}`);
    assert.equal(
      (await response.json()).error.code,
      'AUTHENTICATION_REQUIRED',
      `${route[0]} ${route[1]}`,
    );
  }
});

test('authenticated cart requests reach the database-backed handler', async (t) => {
  const { server, baseUrl } = await startServer();
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));

  for (const route of [['POST', '/api/v1/carts', {}]]) {
    const response = await request(
      baseUrl,
      route,
      'Bearer valid-test-session',
    );
    assert.equal(response.status, 503, `${route[0]} ${route[1]}`);
    assert.equal(
      (await response.json()).error.code,
      'DATABASE_UNAVAILABLE',
      `${route[0]} ${route[1]}`,
    );
  }
});

test('payment verification requires a valid signature and duplicate callbacks are idempotent', async (t) => {
  const keySecret = 'test-only-backend-secret';
  const orderId = 'c0d548ae-8954-4d7b-b125-3be24917267f';
  const razorpayOrderId = 'order_test_123';
  const razorpayPaymentId = 'pay_test_456';
  const signature = createHmac('sha256', keySecret)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest('hex');
  const payment = {
    payment_attempt_id: 'payment-attempt-id',
    provider_order_id: razorpayOrderId,
    provider_payment_id: null,
    total_minor: '1000',
    currency: 'INR',
    payment_status: 'pending',
    order_id: orderId,
    order_status: 'payment_pending',
    items_subtotal_minor: '900',
    delivery_fee_minor: '100',
    discount_minor: '0',
  };
  let providerFetchCount = 0;
  const databasePool = {
    async query(sql) {
      if (sql.includes('count(*)')) return { rows: [{ count: 1 }] };
      return { rows: [{ ...payment }] };
    },
    async connect() {
      return {
        async query(sql, params = []) {
          if (sql.includes('SELECT') && sql.includes('order_payment_attempts')) {
            return { rows: [{ ...payment }] };
          }
          if (sql.includes('UPDATE app.order_payment_attempts')) {
            payment.payment_status = 'verified';
            payment.provider_payment_id = params[1];
          }
          if (sql.includes("SET status = 'placed'")) {
            payment.order_status = 'placed';
            return { rows: [{ id: orderId }] };
          }
          if (sql.includes('count(*)')) return { rows: [{ count: 1 }] };
          return { rows: [] };
        },
        release() {},
      };
    },
  };
  const razorpayClient = {
    payments: {
      async fetch() {
        providerFetchCount += 1;
        return {
          order_id: razorpayOrderId,
          amount: 1000,
          currency: 'INR',
          status: 'captured',
        };
      },
    },
  };
  const { server, baseUrl } = await startServer({
    databasePool,
    razorpayClient,
    razorpayKeySecret: keySecret,
  });
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));
  const route = [
    'POST',
    `/api/v1/orders/${orderId}/verify-payment`,
    {
      razorpayOrderId,
      razorpayPaymentId,
      razorpaySignature: signature,
    },
  ];

  const invalid = await request(
    baseUrl,
    [
      'POST',
      route[1],
      { ...route[2], razorpaySignature: '0'.repeat(64) },
    ],
    '******',
  );
  const invalidBody = await invalid.json();
  assert.equal(invalid.status, 400, JSON.stringify(invalidBody));
  assert.equal(invalidBody.error.code, 'PAYMENT_VERIFICATION_FAILED');
  assert.equal(providerFetchCount, 0);

  const first = await request(baseUrl, route, '******');
  assert.equal(first.status, 200);
  const firstBody = await first.json();
  assert.equal(firstBody.data.paymentStatus, 'paid');
  assert.equal(firstBody.data.paymentVerified, true);
  assert.equal(firstBody.data.status, 'placed');

  const duplicate = await request(baseUrl, route, '******');
  assert.equal(duplicate.status, 200);
  assert.equal((await duplicate.json()).data.paymentVerified, true);
  assert.equal(providerFetchCount, 1);
});
