const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');

async function startTestServer(t, databasePool) {
  const server = http.createServer(createApp({ databasePool }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

test('lists only public shops and passes filters and pagination as SQL parameters', async (t) => {
  const calls = [];
  const databasePool = {
    async query(sql, params = []) {
      calls.push({ sql, params });
      return {
        rows: [
          {
            id: '57a85a0c-7081-4eb7-9c13-4b9842216b54',
            name: 'Mandapeta Kitchen',
            partner_type: 'restaurant',
          },
        ],
      };
    },
  };
  const baseUrl = await startTestServer(t, databasePool);
  const response = await fetch(
    `${baseUrl}/api/v1/shops?partnerType=restaurant&q=kitchen&limit=5&offset=10`,
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    data: [
      {
        id: '57a85a0c-7081-4eb7-9c13-4b9842216b54',
        name: 'Mandapeta Kitchen',
        partner_type: 'restaurant',
      },
    ],
    pagination: { limit: 5, offset: 10 },
  });
  assert.match(calls[0].sql, /s\.status = 'active'/);
  assert.match(calls[0].sql, /p\.status = 'approved'/);
  assert.deepEqual(calls[0].params, ['restaurant', 'kitchen', 5, 10]);
});

test('lists active dynamic partner categories from PostgreSQL', async (t) => {
  const calls = [];
  const databasePool = {
    async query(sql, params = []) {
      calls.push({ sql, params });
      return {
        rows: [
          { partner_type: 'bakery', partner_count: 2 },
          { partner_type: 'sweet_shop', partner_count: 1 },
        ],
      };
    },
  };
  const baseUrl = await startTestServer(t, databasePool);
  const response = await fetch(`${baseUrl}/api/v1/partner-categories`);

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    data: [
      {
        partner_type: 'bakery',
        display_name: 'Bakery',
        partner_count: 2,
      },
      {
        partner_type: 'sweet_shop',
        display_name: 'Sweet Shop',
        partner_count: 1,
      },
    ],
  });
  assert.match(calls[0].sql, /FROM app\.partners/);
  assert.match(calls[0].sql, /WHERE is_active = true/);
  assert.match(calls[0].sql, /GROUP BY partner_type/);
  assert.deepEqual(calls[0].params, []);
});

test('searches catalog products with parameterized filters and pagination', async (t) => {
  const calls = [];
  const databasePool = {
    async query(sql, params) {
      calls.push({ sql, params });
      return { rows: [] };
    },
  };
  const baseUrl = await startTestServer(t, databasePool);
  const search = "tea%' OR true --";
  const response = await fetch(
    `${baseUrl}/api/v1/products?shopId=57a85a0c-7081-4eb7-9c13-4b9842216b54` +
      `&categoryId=7512bb41-8bcb-4237-996e-eb54635b5b74` +
      `&partnerType=grocery&q=${encodeURIComponent(search)}&limit=7&offset=2`,
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    data: [],
    pagination: { limit: 7, offset: 2 },
  });
  assert.match(calls[0].sql, /pr\.status = 'active'/);
  assert.match(calls[0].sql, /pr\.is_available = true/);
  assert.deepEqual(calls[0].params, [
    '57a85a0c-7081-4eb7-9c13-4b9842216b54',
    '7512bb41-8bcb-4237-996e-eb54635b5b74',
    'grocery',
    search,
    7,
    2,
  ]);
});

test('reads active shop categories and product details from the catalog tables', async (t) => {
  const calls = [];
  const category = {
    id: '7512bb41-8bcb-4237-996e-eb54635b5b74',
    name: 'Hot Drinks',
  };
  const product = {
    id: '57a85a0c-7081-4eb7-9c13-4b9842216b54',
    name: 'Tea',
    price_minor: '1500',
    currency: 'INR',
  };
  const databasePool = {
    async query(sql, params) {
      calls.push({ sql, params });
      return { rows: [calls.length === 1 ? category : product] };
    },
  };
  const baseUrl = await startTestServer(t, databasePool);
  const shopId = '49aa4a5f-9573-4e4c-a8d6-df98dfdab5fb';
  const categoryResponse = await fetch(
    `${baseUrl}/api/v1/shops/${shopId}/categories`,
  );
  assert.equal(categoryResponse.status, 200);
  assert.deepEqual(await categoryResponse.json(), { data: [category] });

  const productResponse = await fetch(
    `${baseUrl}/api/v1/products/${product.id}`,
  );
  assert.equal(productResponse.status, 200);
  assert.deepEqual(await productResponse.json(), { data: product });

  assert.deepEqual(calls.map((call) => call.params), [[shopId], [product.id]]);
  assert.match(calls[0].sql, /app\.categories/);
  assert.match(calls[0].sql, /c\.is_active = true/);
  assert.match(calls[1].sql, /app\.products/);
  assert.match(calls[1].sql, /p\.status = 'approved'/);
});

test('validates ids and query options before accessing PostgreSQL', async (t) => {
  let queryCount = 0;
  const databasePool = {
    async query() {
      queryCount++;
      return { rows: [] };
    },
  };
  const baseUrl = await startTestServer(t, databasePool);

  const invalidShop = await fetch(
    `${baseUrl}/api/v1/shops?partnerType=bad%2Ftype`,
  );
  assert.equal(invalidShop.status, 400);
  assert.deepEqual(await invalidShop.json(), {
    error: {
      code: 'INVALID_REQUEST',
      message:
        'partnerType must be a lowercase identifier using letters, digits, or underscores.',
    },
  });

  const invalidProduct = await fetch(
    `${baseUrl}/api/v1/products/not-a-uuid`,
  );
  assert.equal(invalidProduct.status, 400);
  assert.deepEqual(await invalidProduct.json(), {
    error: {
      code: 'INVALID_REQUEST',
      message: 'productId must be a valid UUID.',
    },
  });

  const invalidPagination = await fetch(
    `${baseUrl}/api/v1/products?limit=101`,
  );
  assert.equal(invalidPagination.status, 400);
  const nonDecimalOffset = await fetch(
    `${baseUrl}/api/v1/products?offset=1e2`,
  );
  assert.equal(nonDecimalOffset.status, 400);
  assert.equal(queryCount, 0);
});

test('filters catalog using partner types introduced after deployment', async (t) => {
  const calls = [];
  const databasePool = {
    async query(sql, params) {
      calls.push({ sql, params });
      return { rows: [] };
    },
  };
  const baseUrl = await startTestServer(t, databasePool);
  const response = await fetch(
    `${baseUrl}/api/v1/shops?partnerType=sweet_shop`,
  );

  assert.equal(response.status, 200);
  assert.deepEqual(calls[0].params, ['sweet_shop', null, 20, 0]);
});

test('returns generic unavailable and database error responses', async (t) => {
  const unavailableUrl = await startTestServer(t, null);
  const unavailableCategories = await fetch(
    `${unavailableUrl}/api/v1/partner-categories`,
  );
  assert.equal(unavailableCategories.status, 503);
  assert.deepEqual(await unavailableCategories.json(), {
    error: {
      code: 'DATABASE_UNAVAILABLE',
      message: 'The catalog is temporarily unavailable.',
    },
  });

  const unavailable = await fetch(`${unavailableUrl}/api/v1/shops`);
  assert.equal(unavailable.status, 503);
  assert.deepEqual(await unavailable.json(), {
    error: {
      code: 'DATABASE_UNAVAILABLE',
      message: 'The catalog is temporarily unavailable.',
    },
  });

  const failingUrl = await startTestServer(t, {
    async query() {
      throw new Error('private database details');
    },
  });
  const failure = await fetch(`${failingUrl}/api/v1/shops`);
  assert.equal(failure.status, 500);
  const failureBody = await failure.json();
  assert.deepEqual(failureBody, {
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'An unexpected error occurred.',
    },
  });
  assert.equal(JSON.stringify(failureBody).includes('private'), false);
});
