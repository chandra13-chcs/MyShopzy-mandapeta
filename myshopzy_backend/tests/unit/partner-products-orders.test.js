const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const { createApp } = require('../../src/app');
const {
  ORDER_TRANSITIONS,
  createPartnerProductOrderRouter,
  validateAttributes,
  validateProductInput,
  validateVariants,
} = require('../../src/modules/partner-types/products-orders-routes');
const { getPartnerTypeProfile } = require('../../src/modules/partner-types/profiles');

const partnerA = '11111111-1111-4111-8111-111111111111';
const partnerB = '22222222-2222-4222-8222-222222222222';
const shopA = '33333333-3333-4333-8333-333333333333';
const categoryA = '44444444-4444-4444-8444-444444444444';
const productA = '55555555-5555-4555-8555-555555555555';
const orderA = '66666666-6666-4666-8666-666666666666';

function validVariant(overrides = {}) {
  return {
    label: '1 kg',
    unit: 'kg',
    quantity: 1,
    price_minor: 25000,
    stock: 5,
    sku: null,
    is_available: true,
    sort_order: 0,
    ...overrides,
  };
}

async function startServer(t, pool) {
  const authenticatePartner = (req, res, next) => {
    req.partnerContext = {
      userId: '77777777-7777-4777-8777-777777777777',
      partnerId: partnerA,
      role: 'owner',
      partnerType: 'meat',
      shopIds: [shopA],
    };
    next();
  };
  const router = createPartnerProductOrderRouter({ databasePool: pool });
  const app = createApp({ databasePool: pool, authenticatePartner });
  app.use('/api/v1', router);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));
  return `http://127.0.0.1:${server.address().port}`;
}

function createReadPool() {
  const calls = [];
  return {
    calls,
    async query(sql, params = []) {
      calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      if (/SELECT\s+pr\.id,/i.test(sql)) {
        if (params[1] === partnerA && params[0] === productA) {
          return { rows: [{ id: productA, partner_id: partnerA, name: 'Partner A item' }] };
        }
        return { rows: [] };
      }
      if (/SELECT\s+o\.id,/i.test(sql)) {
        return { rows: [] };
      }
      return { rows: [] };
    },
  };
}

test('profiles validate required extra fields and reject unsupported or malformed values', () => {
  const meat = getPartnerTypeProfile('meat');
  assert.throws(
    () => validateAttributes({}, meat),
    (error) => error.code === 'INVALID_PRODUCT_ATTRIBUTES',
  );
  assert.throws(
    () => validateAttributes({ cutType: 'unknown', freshOrFrozen: 'fresh' }, meat),
    (error) => error.code === 'INVALID_PRODUCT_ATTRIBUTES',
  );
  assert.throws(
    () => validateProductInput({
      name: 'a'.repeat(81),
      categoryId: categoryA,
      attributes: { cutType: 'whole', freshOrFrozen: 'fresh' },
      variants: [validVariant()],
    }, meat),
    (error) => error.code === 'INVALID_PRODUCT',
  );
  assert.throws(
    () => validateVariants([validVariant({ unit: 'ml' })], meat),
    (error) => error.code === 'INVALID_VARIANTS',
  );
  assert.throws(
    () => validateVariants(
      Array.from({ length: 9 }, (_, index) =>
        validVariant({ label: `size-${index}` })),
      meat,
    ),
    (error) => error.code === 'INVALID_VARIANTS',
  );
  assert.throws(
    () => validateVariants([validVariant({ label: 'a'.repeat(21) })], meat),
    (error) => error.code === 'INVALID_VARIANTS',
  );
});

test('partner A cannot read partner B products or orders', async (t) => {
  const pool = createReadPool();
  const baseUrl = await startServer(t, pool);
  const productResponse = await fetch(`${baseUrl}/api/v1/partner/products/${productA}`);
  const orderResponse = await fetch(`${baseUrl}/api/v1/partner/orders/${orderA}`);

  assert.equal(productResponse.status, 404);
  assert.equal((await productResponse.json()).error.code, 'PRODUCT_NOT_FOUND');
  assert.equal(orderResponse.status, 404);
  assert.equal((await orderResponse.json()).error.code, 'ORDER_NOT_FOUND');
  assert.deepEqual(
    pool.calls.find(({ sql }) => /FROM app\.products/.test(sql)).params,
    [productA, partnerA],
  );
  assert.deepEqual(
    pool.calls.find(({ sql }) => /FROM app\.orders/.test(sql)).params,
    [orderA, partnerA],
  );
});

test('partner A cannot edit partner B product records', async (t) => {
  const calls = [];
  const client = {
    async query(sql, params = []) {
      calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      if (/SELECT\s+pr\.\*/i.test(sql)) return { rows: [] };
      return { rows: [] };
    },
    release() {},
  };
  const pool = { connect: async () => client };
  const baseUrl = await startServer(t, pool);
  const response = await fetch(`${baseUrl}/api/v1/partner/products/${productA}`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ name: 'Attempted edit' }),
  });

  assert.equal(response.status, 404);
  assert.equal((await response.json()).error.code, 'PRODUCT_NOT_FOUND');
  assert.deepEqual(
    calls.find(({ sql }) => /FROM app\.products/.test(sql)).params,
    [productA, partnerA],
  );
  assert.equal(calls.some(({ sql }) => /^UPDATE app\.products/.test(sql)), false);
  assert.ok(calls.some(({ sql }) => sql === 'ROLLBACK'));
});

test('product creation validates before writing and rolls back product plus variants atomically', async (t) => {
  const calls = [];
  const client = {
    async query(sql, params = []) {
      const normalized = sql.replace(/\s+/g, ' ').trim();
      calls.push({ sql: normalized, params });
      if (/SELECT id\s+FROM app\.shops/.test(sql)) return { rows: [{ id: shopA }] };
      if (/SELECT id\s+FROM app\.categories/.test(sql)) {
        return { rows: [{ id: categoryA }] };
      }
      if (/INSERT INTO app\.product_variants/.test(sql)) {
        throw new Error('Injected variant write failure.');
      }
      return { rows: [] };
    },
    release() {},
  };
  const pool = { connect: async () => client };
  const baseUrl = await startServer(t, pool);
  const invalid = await fetch(`${baseUrl}/api/v1/partner/products`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      name: 'Chicken',
      categoryId: categoryA,
      attributes: { cutType: 'whole' },
      variants: [validVariant()],
    }),
  });
  assert.equal(invalid.status, 400);
  assert.equal((await invalid.json()).error.code, 'INVALID_PRODUCT_ATTRIBUTES');
  assert.equal(calls.length, 0);

  const failed = await fetch(`${baseUrl}/api/v1/partner/products`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      name: 'Chicken Curry Cut',
      categoryId: categoryA,
      attributes: { cutType: 'curry_cut', freshOrFrozen: 'fresh' },
      variants: [validVariant()],
    }),
  });
  assert.equal(failed.status, 500);
  assert.ok(calls.some(({ sql }) => /^INSERT INTO app\.products/.test(sql)));
  assert.ok(calls.some(({ sql }) => /^INSERT INTO app\.product_variants/.test(sql)));
  assert.equal(calls.at(-1).sql, 'ROLLBACK');
  assert.equal(calls.some(({ sql }) => sql === 'COMMIT'), false);
});

test('order status transitions allow only the requested forward path', () => {
  assert.deepEqual(ORDER_TRANSITIONS, {
    placed: ['accepted', 'rejected'],
    accepted: ['preparing'],
    preparing: ['ready'],
    ready: [],
  });
  assert.equal(ORDER_TRANSITIONS.placed.includes('accepted'), true);
  assert.equal(ORDER_TRANSITIONS.placed.includes('rejected'), true);
  assert.equal(ORDER_TRANSITIONS.accepted.includes('preparing'), true);
  assert.equal(ORDER_TRANSITIONS.preparing.includes('ready'), true);
  assert.equal(ORDER_TRANSITIONS.ready.includes('preparing'), false);
});

test('returns 409 and leaves an order unchanged on an invalid transition', async (t) => {
  const calls = [];
  const client = {
    async query(sql, params = []) {
      const normalized = sql.replace(/\s+/g, ' ').trim();
      calls.push({ sql: normalized, params });
      if (/SELECT id, status\s+FROM app\.orders/.test(sql)) {
        return { rows: [{ id: orderA, status: 'placed' }] };
      }
      return { rows: [] };
    },
    release() {},
  };
  const pool = { connect: async () => client };
  const baseUrl = await startServer(t, pool);
  const response = await fetch(`${baseUrl}/api/v1/partner/orders/${orderA}/status`, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ status: 'preparing' }),
  });

  assert.equal(response.status, 409);
  assert.equal((await response.json()).error.code, 'INVALID_ORDER_TRANSITION');
  assert.deepEqual(calls[1].params, [orderA, partnerA]);
  assert.equal(calls.some(({ sql }) => /^UPDATE app\.orders/.test(sql)), false);
  assert.equal(calls.at(-1).sql, 'ROLLBACK');
});
