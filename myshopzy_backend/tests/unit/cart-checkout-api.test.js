const assert = require('node:assert/strict');
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
];

async function startServer() {
  const authenticateCustomer = (req, res, next) => {
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
  const server = createApp({ authenticateCustomer }).listen(0);
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

test('authenticated cart and checkout requests fail closed until carts have customer ownership', async (t) => {
  const { server, baseUrl } = await startServer();
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));

  for (const route of protectedRequests) {
    const response = await request(
      baseUrl,
      route,
      'Bearer valid-test-session',
    );
    assert.equal(response.status, 503, `${route[0]} ${route[1]}`);
    assert.equal(
      (await response.json()).error.code,
      'CART_OWNERSHIP_UNAVAILABLE',
      `${route[0]} ${route[1]}`,
    );
  }
});
