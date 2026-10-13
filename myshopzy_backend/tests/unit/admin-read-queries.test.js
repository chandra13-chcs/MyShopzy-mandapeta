const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const { createApp } = require('../../src/app');

const {
  QueryValidationError,
  getResource,
  listResource,
  parseListQuery,
} = require('../../src/modules/admin-read/queries');

const partnerId = 'e6c203e8-8254-47db-883c-0b8fb688b14b';
const resourceNames = ['orders', 'customers', 'partners', 'products'];

function createPool({ rows = [], total = '0', failOnCall } = {}) {
  const calls = [];
  return {
    calls,
    async query(sql, params) {
      calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      if (failOnCall === calls.length) throw new Error('private database diagnostic');
      if (calls.length === 1 && sql.includes('count(*)')) {
        return { rows: [{ total }] };
      }
      return { rows };
    },
  };
}

test('validates pagination defaults, bounds, and decimal-only inputs', () => {
  assert.deepEqual(parseListQuery('orders', {}), {
    limit: 25,
    offset: 0,
    search: null,
    sortField: 'o.placed_at',
    sortDirection: 'DESC',
    filters: [],
  });
  assert.equal(parseListQuery('products', { limit: '100', offset: '42' }).offset, 42);

  for (const query of [
    { limit: '0' },
    { limit: '101' },
    { limit: '1e2' },
    { offset: '-1' },
    { offset: '9007199254740992' },
    { limit: ['25'] },
  ]) {
    assert.throws(() => parseListQuery('orders', query), QueryValidationError);
  }
});

test('rejects unsupported filters and sort fields before querying', async () => {
  const pool = createPool();
  for (const [resource, query] of [
    ['orders', { sort: 'totalMinor; DROP TABLE app.orders:desc' }],
    ['orders', { status: 'completed' }],
    ['customers', { status: 'pending' }],
    ['partners', { partnerType: 'bakery' }],
    ['products', { status: 'suspended' }],
    ['products', { listingStatus: 'pending' }],
    ['products', { availability: 'yes' }],
    ['products', { partnerId: 'not-a-uuid' }],
    ['products', { status: 'active', listingStatus: 'archived' }],
    ['products', { from: '2026-10-01T00:00:00Z', createdFrom: '2026-10-02T00:00:00Z' }],
    ['customers', { paymentState: 'paid' }],
  ]) {
    assert.throws(() => parseListQuery(resource, query), QueryValidationError);
    await assert.rejects(listResource(pool, resource, query), QueryValidationError);
  }
  assert.equal(pool.calls.length, 0);
});

test('validates time windows and accepts documented allow-listed sort fields', () => {
  assert.throws(
    () => parseListQuery('orders', { from: '2026-10-02T00:00:00Z', to: '2026-10-02T00:00:00Z' }),
    /from must be earlier than to/,
  );
  assert.throws(
    () => parseListQuery('orders', { from: '2026-10-02' }),
    /RFC 3339 timestamp/,
  );
  assert.equal(
    parseListQuery('orders', {
      from: '2026-10-01T00:00:00+05:30',
      to: '2026-11-01T00:00:00+05:30',
      sort: 'totalMinor:asc',
    }).sortDirection,
    'ASC',
  );
  assert.equal(parseListQuery('partners', { sort: 'name:desc' }).sortField, 'p.name');
});

test('strictly validates calendar dates and rejects invalid timestamps before querying', async () => {
  assert.equal(
    parseListQuery('orders', { from: '2024-02-29T23:59:59.123+05:30' }).filters[0].value,
    '2024-02-29T23:59:59.123+05:30',
  );
  assert.equal(
    parseListQuery('orders', { from: '2026-10-13T00:00:00Z' }).filters[0].value,
    '2026-10-13T00:00:00Z',
  );

  const pool = createPool();
  for (const from of [
    '2026-02-31T00:00:00Z',
    '2026-02-29T00:00:00Z',
    '2026-04-31T00:00:00Z',
    '2026-13-01T00:00:00Z',
    '2026-10-13T24:00:00Z',
    '2026-10-13T00:00:00+24:00',
  ]) {
    assert.throws(
      () => parseListQuery('orders', { from }),
      /from must be a valid RFC 3339 timestamp/,
    );
    await assert.rejects(
      listResource(pool, 'orders', { from }),
      /from must be a valid RFC 3339 timestamp/,
    );
  }
  await assert.rejects(
    listResource(pool, 'products', { createdFrom: '2026-02-31T00:00:00Z' }),
    /from must be a valid RFC 3339 timestamp/,
  );
  assert.equal(pool.calls.length, 0);
});

test('maps prepared Product query aliases to existing persisted query fields', async () => {
  const from = '2026-10-01T00:00:00+05:30';
  const to = '2026-11-01T00:00:00+05:30';
  const parsed = parseListQuery('products', {
    listingStatus: 'archived',
    createdFrom: from,
    createdTo: to,
    sort: 'listingStatus:desc',
  });
  assert.deepEqual(parsed.filters.map(({ key, field, operator, value }) => ({
    key, field, operator, value,
  })), [
    { key: 'status', field: 'pr.status', operator: undefined, value: 'archived' },
    { key: 'from', field: 'pr.created_at', operator: '>=', value: from },
    { key: 'to', field: 'pr.created_at', operator: '<', value: to },
  ]);
  assert.equal(parsed.sortField, 'pr.status');
  assert.equal(parsed.sortDirection, 'DESC');

  const pool = createPool({ rows: [{ id: 'product-id' }], total: '1' });
  await listResource(pool, 'products', {
    listingStatus: 'active',
    createdFrom: from,
    createdTo: to,
    sort: 'listingStatus:asc',
  });
  assert.match(pool.calls[1].sql, /pr\.status AS "status"/);
  assert.match(pool.calls[1].sql, /pr\.status AS "listingStatus"/);
  assert.match(pool.calls[1].sql, /pr\.price_minor AS "priceMinor"/);
  assert.match(pool.calls[1].sql, /pr\.currency AS "currency"/);
  assert.match(pool.calls[1].sql, /pr\.is_available AS "isAvailable"/);
  assert.match(pool.calls[1].sql, /pr\.created_at AS "createdAt"/);
  assert.doesNotMatch(pool.calls[1].sql, /pr\.description|pr\.attributes/);
  assert.match(pool.calls[0].sql, /pr\.status = \$1/);
  assert.match(pool.calls[0].sql, /pr\.created_at >= \$2/);
  assert.match(pool.calls[0].sql, /pr\.created_at < \$3/);
  assert.match(pool.calls[1].sql, /ORDER BY pr\.status ASC/);
  assert.deepEqual(pool.calls[0].params, ['active', from, to]);
  assert.equal(pool.calls[1].params.at(-2), 25);
  assert.equal(pool.calls[1].params.at(-1), 0);
});

test('lists only source-backed fields with parameterized filters and deterministic sorting', async () => {
  for (const resource of resourceNames) {
    const pool = createPool({
      rows: [{ id: 'row-id' }],
      total: '1',
    });
    const query = resource === 'orders'
      ? { q: 'shop', status: 'delivered', partnerId, from: '2026-10-01T00:00:00Z', limit: '5', offset: '10', sort: 'placedAt:asc' }
      : resource === 'products'
        ? { q: 'tea', partnerId, availability: 'false', limit: '5', offset: '10', sort: 'name:desc' }
        : resource === 'partners'
          ? { q: 'market', status: 'pending', limit: '5', offset: '10', sort: 'partnerType:asc' }
          : { q: 'customer', status: 'active', limit: '5', offset: '10', sort: 'displayName:asc' };
    const result = await listResource(pool, resource, query);

    assert.deepEqual(result, {
      data: [{ id: 'row-id' }],
      pagination: { limit: 5, offset: 10, total: 1 },
    });
    assert.equal(pool.calls.length, 2);
    assert.match(pool.calls[0].sql, /SELECT count\(\*\)::text AS total/);
    assert.match(pool.calls[1].sql, /ORDER BY .* (ASC|DESC), .*\.id ASC LIMIT/);
    assert.ok(pool.calls[1].params.includes(query.q));
    assert.ok(pool.calls[1].params.includes(5));
    assert.ok(pool.calls[1].params.includes(10));
    assert.doesNotMatch(pool.calls[1].sql, /delivery_address_snapshot|contact_email|contact_phone/);
    if (resource === 'customers') {
      assert.match(pool.calls[1].sql, /u\.system_role = 'customer'/);
    }
  }
});

test('returns a true empty page with a zero total', async () => {
  const pool = createPool();
  const result = await listResource(pool, 'partners', { limit: '25', offset: '50' });
  assert.deepEqual(result, {
    data: [],
    pagination: { limit: 25, offset: 50, total: 0 },
  });
});

test('rejects unavailable database, propagates database errors, and validates details', async () => {
  await assert.rejects(
    listResource(null, 'orders'),
    (error) => error.status === 503 && error.code === 'DATABASE_UNAVAILABLE',
  );

  const failingPool = createPool({ failOnCall: 1 });
  await assert.rejects(listResource(failingPool, 'orders'), /private database diagnostic/);

  const pool = createPool({ rows: [] });
  assert.equal(await getResource(pool, 'partners', partnerId), null);
  assert.equal(pool.calls.length, 1);
  await assert.rejects(getResource(pool, 'orders', 'not-a-uuid'), QueryValidationError);
  assert.equal(pool.calls.length, 1);
});

test('returns approved order-item fields and linked partner shops for detail preparation', async () => {
  const orderPool = {
    calls: [],
    async query(sql, params) {
      this.calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      if (this.calls.length === 1) return { rows: [{ id: 'order-id', totalMinor: '1000' }] };
      return {
        rows: [{
          productId: 'product-id',
          productName: 'Tea',
          sku: 'TEA-1',
          unitPriceMinor: '1000',
          quantity: 1,
          lineTotalMinor: '1000',
          currency: 'USD',
          variantSnapshot: { customer: { email: 'private@example.test' } },
          unexpected: { nested: true },
        }],
      };
    },
  };
  const order = await getResource(orderPool, 'orders', partnerId);
  assert.deepEqual(order.items, [{
    productId: 'product-id',
    productName: 'Tea',
    sku: 'TEA-1',
    unitPriceMinor: '1000',
    quantity: 1,
    lineTotalMinor: '1000',
    currency: 'USD',
  }]);
  assert.match(orderPool.calls[1].sql, /FROM app\.order_items/);
  assert.doesNotMatch(orderPool.calls[1].sql, /variant_snapshot|variantSnapshot/);
  assert.doesNotMatch(JSON.stringify(order), /private@example\.test|unexpected|variantSnapshot/);
  assert.deepEqual(orderPool.calls[1].params, [partnerId]);

  const partnerPool = {
    calls: [],
    async query(sql, params) {
      this.calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      return { rows: this.calls.length === 1 ? [{ id: partnerId }] : [{ id: 'shop-id', status: 'active' }] };
    },
  };
  const partner = await getResource(partnerPool, 'partners', partnerId);
  assert.deepEqual(partner.shops, [{ id: 'shop-id', status: 'active' }]);
  assert.match(partnerPool.calls[1].sql, /FROM app\.shops/);
});

test('prepares customer and product detail from persisted account and catalogue fields', async () => {
  const customerPool = createPool({
    rows: [{
      id: partnerId,
      displayName: 'Customer',
      status: 'active',
      createdAt: '2026-10-01T00:00:00.000Z',
    }],
  });
  const customer = await getResource(customerPool, 'customers', partnerId);
  assert.equal(customer.id, partnerId);
  assert.match(customerPool.calls[0].sql, /u\.system_role = 'customer'/);
  assert.doesNotMatch(customerPool.calls[0].sql, /email|phone/);

  const productPool = createPool({
    rows: [{
      id: partnerId,
      name: 'Product',
      status: 'active',
      listingStatus: 'active',
      updatedAt: '2026-10-02T00:00:00.000Z',
    }],
  });
  const product = await getResource(productPool, 'products', partnerId);
  assert.equal(product.name, 'Product');
  assert.equal(product.status, 'active');
  assert.equal(product.listingStatus, 'active');
  assert.equal(product.updatedAt, '2026-10-02T00:00:00.000Z');
  assert.equal(Object.hasOwn(product, 'description'), false);
  assert.equal(Object.hasOwn(product, 'attributes'), false);
  assert.match(productPool.calls[0].sql, /pr\.status AS "status"/);
  assert.match(productPool.calls[0].sql, /pr\.status AS "listingStatus"/);
  assert.match(productPool.calls[0].sql, /pr\.updated_at AS "updatedAt"/);
  assert.match(productPool.calls[0].sql, /pr\.price_minor AS "priceMinor"/);
  assert.match(productPool.calls[0].sql, /pr\.currency AS "currency"/);
  assert.match(productPool.calls[0].sql, /pr\.is_available AS "isAvailable"/);
  assert.doesNotMatch(productPool.calls[0].sql, /pr\.description|pr\.attributes/);
  assert.match(productPool.calls[0].sql, /c\.shop_id = pr\.shop_id AND c\.partner_id = pr\.partner_id/);
});

test('requires a database pool for every resource and supports exactly the four batch resources', async () => {
  for (const resource of resourceNames) {
    await assert.rejects(listResource(undefined, resource), (error) => error.status === 503);
  }
  assert.throws(() => parseListQuery('payments', {}), /Unknown read-only resource/);
  await assert.rejects(
    listResource({ query: async () => ({ rows: [] }) }, 'payments'),
    /Unknown read-only resource/,
  );
});

test('does not register any prepared admin read endpoint before authorization is implemented', async (t) => {
  let databaseCalls = 0;
  const server = http.createServer(createApp({
    databasePool: {
      async query() {
        databaseCalls++;
        return { rows: [] };
      },
    },
  }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  for (const path of [
    '/api/v1/admin/orders',
    '/api/v1/admin/customers',
    '/api/v1/admin/partners',
    '/api/v1/admin/catalog/products',
  ]) {
    const response = await fetch(`${baseUrl}${path}`);
    assert.equal(response.status, 404);
    assert.deepEqual(await response.json(), {
      error: { code: 'NOT_FOUND', message: 'API endpoint not found.' },
    });
  }
  assert.equal(databaseCalls, 0);
});
