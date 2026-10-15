const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');

const productId = '57a85a0c-7081-4eb7-9c13-4b9842216b54';
const otherProductId = '7512bb41-8bcb-4237-996e-eb54635b5b74';
const otherShopProductId = '7b579b9a-d128-40f2-8ee3-5c7018b69a2d';
const shopId = '49aa4a5f-9573-4e4c-a8d6-df98dfdab5fb';
const otherShopId = '2301e7cc-e405-4148-8cfb-ddd8b59f6179';
const partnerId = 'bc33d625-bbc1-4589-b2b2-6839d1f358d9';
const otherPartnerId = '87420ef0-37da-4f82-a664-ce364390ce36';
const customerId = '27dcad4a-f166-4fc8-a224-3d1c099dd459';
const deliveryAddress = {
  formattedAddress: '12 Green Park Road, Mandapeta',
  pincode: '533308',
};

function createDatabase({ failOn } = {}) {
  let state = {
    carts: {},
    items: {},
    products: {
      [productId]: {
        id: productId,
        shop_id: shopId,
        partner_id: partnerId,
        name: 'Tea',
        sku: 'TEA-01',
        price_minor: '1500',
        currency: 'INR',
        inventory_quantity: 8,
        is_available: true,
        product_status: 'active',
        shop_status: 'active',
        partner_status: 'approved',
      },
      [otherProductId]: {
        id: otherProductId,
        shop_id: shopId,
        partner_id: partnerId,
        name: 'Coffee',
        sku: 'COFFEE-01',
        price_minor: '2500',
        currency: 'INR',
        inventory_quantity: null,
        is_available: true,
        product_status: 'active',
        shop_status: 'active',
        partner_status: 'approved',
      },
      [otherShopProductId]: {
        id: otherShopProductId,
        shop_id: otherShopId,
        partner_id: otherPartnerId,
        name: 'Bread',
        sku: 'BREAD-01',
        price_minor: '2000',
        currency: 'INR',
        inventory_quantity: 6,
        is_available: true,
        product_status: 'active',
        shop_status: 'active',
        partner_status: 'approved',
      },
    },
    orders: [],
    orderItems: [],
  };
  const queries = [];
  let transactionSnapshot;

  async function query(sql, params = []) {
    const normalized = sql.replace(/\s+/g, ' ').trim();
    queries.push({ sql: normalized, params });
    if (failOn && normalized.includes(failOn)) {
      throw new Error('private database diagnostic');
    }

    if (normalized === 'BEGIN') {
      transactionSnapshot = structuredClone(state);
      return { rows: [], rowCount: 0 };
    }
    if (normalized === 'COMMIT') {
      transactionSnapshot = undefined;
      return { rows: [], rowCount: 0 };
    }
    if (normalized === 'ROLLBACK') {
      state = transactionSnapshot;
      transactionSnapshot = undefined;
      return { rows: [], rowCount: 0 };
    }
    if (normalized.startsWith('INSERT INTO app.customer_carts')) {
      const [id, tokenHash] = params;
      state.carts[id] = {
        id,
        token_hash: tokenHash.toString('hex'),
        shop_id: null,
        partner_id: null,
      };
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('SELECT id, shop_id, partner_id FROM app.customer_carts')) {
      const [tokenHash] = params;
      const cart = Object.values(state.carts).find(
        (candidate) => candidate.token_hash === tokenHash.toString('hex'),
      );
      return { rows: cart ? [{ ...cart }] : [], rowCount: cart ? 1 : 0 };
    }
    if (normalized.startsWith('SELECT p.id, p.shop_id, p.partner_id, p.name')) {
      const product = state.products[params[0]];
      return { rows: product ? [{ ...product }] : [], rowCount: product ? 1 : 0 };
    }
    if (normalized.startsWith('SELECT ci.quantity, p.currency')) {
      const cartItems = Object.values(state.items).filter(
        (item) => item.cart_id === params[0],
      );
      return {
        rows: cartItems.map((item) => ({
          quantity: item.quantity,
          currency: state.products[item.product_id].currency,
        })),
        rowCount: cartItems.length,
      };
    }
    if (
      normalized.startsWith(
        'SELECT quantity FROM app.customer_cart_items WHERE cart_id = $1 AND product_id = $2',
      )
    ) {
      const item = state.items[`${params[0]}:${params[1]}`];
      return { rows: item ? [{ quantity: item.quantity }] : [], rowCount: item ? 1 : 0 };
    }
    if (normalized.startsWith('UPDATE app.customer_carts SET shop_id = $2')) {
      const [id, selectedShopId, selectedPartnerId] = params;
      state.carts[id].shop_id = selectedShopId;
      state.carts[id].partner_id = selectedPartnerId;
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('INSERT INTO app.customer_cart_items')) {
      const [cartId, selectedProductId, selectedShopId, selectedPartnerId, quantity] =
        params;
      state.items[`${cartId}:${selectedProductId}`] = {
        cart_id: cartId,
        product_id: selectedProductId,
        shop_id: selectedShopId,
        partner_id: selectedPartnerId,
        quantity,
      };
      return { rows: [{ quantity }], rowCount: 1 };
    }
    if (normalized.startsWith('UPDATE app.customer_cart_items SET quantity')) {
      const [cartId, selectedProductId, quantity] = params;
      state.items[`${cartId}:${selectedProductId}`].quantity = quantity;
      return { rows: [{ quantity }], rowCount: 1 };
    }
    if (normalized.startsWith('DELETE FROM app.customer_cart_items WHERE cart_id = $1 AND product_id = $2')) {
      const [cartId, selectedProductId] = params;
      const key = `${cartId}:${selectedProductId}`;
      const existed = state.items[key] !== undefined;
      delete state.items[key];
      return { rows: [], rowCount: existed ? 1 : 0 };
    }
    if (normalized.startsWith('SELECT 1 FROM app.customer_cart_items')) {
      const items = Object.values(state.items).filter(
        (item) => item.cart_id === params[0],
      );
      return { rows: items.length ? [{ '?column?': 1 }] : [], rowCount: items.length ? 1 : 0 };
    }
    if (normalized.startsWith('SELECT ci.product_id, ci.quantity')) {
      const items = Object.values(state.items)
        .filter((item) => item.cart_id === params[0])
        .map((item) => ({
          ...item,
          ...state.products[item.product_id],
        }))
        .sort((first, second) => first.name.localeCompare(second.name));
      return { rows: items, rowCount: items.length };
    }
    if (normalized.startsWith('DELETE FROM app.customer_cart_items WHERE cart_id = $1')) {
      const cartId = params[0];
      const items = Object.keys(state.items).filter((key) =>
        key.startsWith(`${cartId}:`),
      );
      for (const key of items) delete state.items[key];
      return { rows: [], rowCount: items.length };
    }
    if (normalized.startsWith('UPDATE app.customer_carts SET shop_id = NULL')) {
      const cart = state.carts[params[0]];
      cart.shop_id = null;
      cart.partner_id = null;
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('SELECT c.user_id FROM app.customers')) {
      return params[0] === customerId
        ? { rows: [{ user_id: customerId }], rowCount: 1 }
        : { rows: [], rowCount: 0 };
    }
    if (normalized.startsWith('SELECT 1 FROM app.serviceable_pincodes')) {
      return params[0] === '533308'
        ? { rows: [{ '?column?': 1 }], rowCount: 1 }
        : { rows: [], rowCount: 0 };
    }
    if (normalized.startsWith('INSERT INTO app.orders')) {
      state.orders.push({ params: [...params] });
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('UPDATE app.products SET inventory_quantity')) {
      const [selectedProductId, quantity] = params;
      const product = state.products[selectedProductId];
      if (product.inventory_quantity < quantity) {
        return { rows: [], rowCount: 0 };
      }
      product.inventory_quantity -= quantity;
      return { rows: [{ id: selectedProductId }], rowCount: 1 };
    }
    if (normalized.startsWith('INSERT INTO app.order_items')) {
      state.orderItems.push({ params: [...params] });
      return { rows: [], rowCount: 1 };
    }

    assert.fail(`Unexpected SQL in test double: ${normalized}`);
  }

  return {
    pool: {
      query,
      async connect() {
        return {
          query,
          release() {},
        };
      },
    },
    queries,
    get state() {
      return state;
    },
  };
}

async function startServer(t, databasePool, { authenticated = false } = {}) {
  const authenticateCustomer = authenticated
    ? (req, res, next) => {
        req.auth = { customerUserId: customerId };
        next();
      }
    : null;
  const server = http.createServer(
    createApp({
      databasePool,
      authenticateCustomer,
    }),
  );
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

async function createCart(baseUrl) {
  const response = await fetch(`${baseUrl}/api/v1/carts`, { method: 'POST' });
  assert.equal(response.status, 201);
  const body = await response.json();
  assert.match(body.data.cartToken, /^[A-Za-z0-9_-]{43}$/);
  return body.data.cartToken;
}

function jsonRequest(method, body, token) {
  return {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { 'x-cart-token': token } : {}),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  };
}

test('creates and manages a capability-token cart without trusting submitted prices', async (t) => {
  const database = createDatabase();
  const baseUrl = await startServer(t, database.pool);
  const token = await createCart(baseUrl);

  const added = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, quantity: 2, priceMinor: 1 }, token),
  );
  assert.equal(added.status, 400);

  const validAdd = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, quantity: 2 }, token),
  );
  assert.equal(validAdd.status, 200);
  assert.deepEqual(await validAdd.json(), {
    data: { productId, quantity: 2 },
  });

  const read = await fetch(`${baseUrl}/api/v1/cart`, {
    headers: { 'x-cart-token': token },
  });
  assert.equal(read.status, 200);
  assert.deepEqual(await read.json(), {
    data: {
      shopId,
      items: [
        {
          productId,
          shopId,
          name: 'Tea',
          sku: 'TEA-01',
          quantity: 2,
          priceMinor: '1500',
          lineTotalMinor: '3000',
          currency: 'INR',
          available: true,
        },
      ],
      itemCount: 2,
      itemSubtotalMinor: '3000',
    },
  });

  const updated = await fetch(
    `${baseUrl}/api/v1/cart/items/${productId}`,
    jsonRequest('PATCH', { quantity: 3 }, token),
  );
  assert.equal(updated.status, 200);
  assert.deepEqual(await updated.json(), { data: { productId, quantity: 3 } });

  const removed = await fetch(
    `${baseUrl}/api/v1/cart/items/${productId}`,
    jsonRequest('DELETE', undefined, token),
  );
  assert.equal(removed.status, 204);

  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId }, token),
  );
  const cleared = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('DELETE', undefined, token),
  );
  assert.equal(cleared.status, 200);
  assert.deepEqual(await cleared.json(), {
    data: { shopId: null, items: [], itemCount: 0, itemSubtotalMinor: '0' },
  });
  assert.equal(Object.keys(database.state.items).length, 0);
});

test('rejects invalid quantities, inactive products, and cross-shop carts', async (t) => {
  const database = createDatabase();
  database.state.products[otherProductId].product_status = 'archived';
  const baseUrl = await startServer(t, database.pool);
  const token = await createCart(baseUrl);

  for (const quantity of [0, -1, 1.5, 100, '2']) {
    const response = await fetch(
      `${baseUrl}/api/v1/cart/items`,
      jsonRequest('POST', { productId, quantity }, token),
    );
    assert.equal(response.status, 400);
  }

  const inactive = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId: otherProductId }, token),
  );
  assert.equal(inactive.status, 409);
  assert.equal((await inactive.json()).error.code, 'PRODUCT_UNAVAILABLE');

  const added = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId }, token),
  );
  assert.equal(added.status, 200);

  const otherShop = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId: otherShopProductId }, token),
  );
  assert.equal(otherShop.status, 409);
  assert.equal((await otherShop.json()).error.code, 'CART_SHOP_MISMATCH');
  assert.equal(Object.keys(database.state.items).length, 1);
});

test('quotes and creates a single-shop order with server-calculated prices and snapshots', async (t) => {
  const database = createDatabase();
  const baseUrl = await startServer(t, database.pool, { authenticated: true });
  const token = await createCart(baseUrl);

  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, quantity: 2 }, token),
  );
  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId: otherProductId, quantity: 1 }, token),
  );
  database.state.products[productId].price_minor = '1750';

  const quote = await fetch(
    `${baseUrl}/api/v1/checkout/quote`,
    jsonRequest('POST', {}, token),
  );
  assert.equal(quote.status, 200);
  assert.deepEqual(await quote.json(), {
    data: {
      items: [
        {
          productId: otherProductId,
          name: 'Coffee',
          quantity: 1,
          priceMinor: '2500',
          lineTotalMinor: '2500',
        },
        {
          productId,
          name: 'Tea',
          quantity: 2,
          priceMinor: '1750',
          lineTotalMinor: '3500',
        },
      ],
      currency: 'INR',
      itemSubtotalMinor: '6000',
      deliveryFeeMinor: '0',
      discountMinor: '0',
      totalMinor: '6000',
    },
  });

  const tampered = await fetch(
    `${baseUrl}/api/v1/orders`,
    jsonRequest(
      'POST',
      { deliveryAddress, itemsSubtotalMinor: '1', totalMinor: '1' },
      token,
    ),
  );
  assert.equal(tampered.status, 400);
  assert.equal(database.state.orders.length, 0);

  const orderResponse = await fetch(
    `${baseUrl}/api/v1/orders`,
    jsonRequest('POST', { deliveryAddress }, token),
  );
  assert.equal(orderResponse.status, 201);
  const order = (await orderResponse.json()).data;
  assert.equal(order.status, 'placed');
  assert.equal(order.currency, 'INR');
  assert.equal(order.itemSubtotalMinor, '6000');
  assert.equal(order.deliveryFeeMinor, '0');
  assert.equal(order.discountMinor, '0');
  assert.equal(order.totalMinor, '6000');
  assert.equal(order.items, 2);

  const insertOrder = database.queries.find((query) =>
    query.sql.startsWith('INSERT INTO app.orders'),
  );
  assert.equal(insertOrder.params[1], customerId);
  assert.equal(insertOrder.params[5], '6000');
  assert.equal(insertOrder.params[8], '6000');
  const teaSnapshot = database.state.orderItems.find(
    ({ params }) => params[4] === productId,
  );
  assert.equal(teaSnapshot.params[5], 'Tea');
  assert.equal(teaSnapshot.params[7], '1750');
  assert.equal(teaSnapshot.params[8], 2);
  assert.equal(teaSnapshot.params[9], '3500');
  assert.equal(
    database.queries.filter((query) =>
      query.sql.startsWith('INSERT INTO app.order_items'),
    ).length,
    2,
  );
  assert.equal(database.state.products[productId].inventory_quantity, 6);
  assert.equal(database.state.orders.length, 1);
  assert.equal(database.state.orderItems.length, 2);
  assert.equal(Object.keys(database.state.items).length, 0);
});

test('rejects cross-shop checkout, unavailable checkout products, and unauthenticated orders', async (t) => {
  const database = createDatabase();
  const publicUrl = await startServer(t, database.pool);
  const token = await createCart(publicUrl);
  await fetch(
    `${publicUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId }, token),
  );

  const transactionsBeforeUnauthenticatedOrder = database.queries.filter(
    (query) => query.sql === 'BEGIN',
  ).length;
  const unauthorized = await fetch(
    `${publicUrl}/api/v1/orders`,
    jsonRequest('POST', { deliveryAddress }, token),
  );
  assert.equal(unauthorized.status, 401);
  assert.equal(
    database.queries.filter((query) => query.sql === 'BEGIN').length,
    transactionsBeforeUnauthenticatedOrder,
  );

  database.state.products[productId].shop_status = 'closed';
  const unavailable = await fetch(
    `${publicUrl}/api/v1/checkout/quote`,
    jsonRequest('POST', {}, token),
  );
  assert.equal(unavailable.status, 409);
  assert.equal((await unavailable.json()).error.code, 'CART_ITEM_UNAVAILABLE');

  const separateCart = await createCart(publicUrl);
  const firstShop = await fetch(
    `${publicUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId: otherShopProductId }, separateCart),
  );
  assert.equal(firstShop.status, 200);
  const crossShopAdd = await fetch(
    `${publicUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId }, separateCart),
  );
  assert.equal(crossShopAdd.status, 409);

  const separateCartId = Object.values(database.state.carts).find(
    (cart) => cart.shop_id === otherShopId,
  ).id;
  database.state.items[`${separateCartId}:${productId}`] = {
    cart_id: separateCartId,
    product_id: productId,
    shop_id: shopId,
    partner_id: partnerId,
    quantity: 1,
  };
  const corruptCheckout = await fetch(
    `${publicUrl}/api/v1/checkout/quote`,
    jsonRequest('POST', {}, separateCart),
  );
  assert.equal(corruptCheckout.status, 409);
  assert.equal((await corruptCheckout.json()).error.code, 'CART_SHOP_MISMATCH');
});

test('rolls back order creation, stock, and cart changes when a snapshot insert fails', async (t) => {
  const database = createDatabase({ failOn: 'INSERT INTO app.order_items' });
  const baseUrl = await startServer(t, database.pool, { authenticated: true });
  const token = await createCart(baseUrl);
  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, quantity: 2 }, token),
  );
  const transactionStart = database.queries.length;

  const response = await fetch(
    `${baseUrl}/api/v1/orders`,
    jsonRequest('POST', { deliveryAddress }, token),
  );
  assert.equal(response.status, 500);
  assert.equal(JSON.stringify(await response.json()).includes('private'), false);
  const orderQueries = database.queries.slice(transactionStart);
  assert.equal(orderQueries.some((query) => query.sql === 'ROLLBACK'), true);
  assert.equal(orderQueries.some((query) => query.sql === 'COMMIT'), false);
  assert.equal(database.state.orders.length, 0);
  assert.equal(database.state.orderItems.length, 0);
  assert.equal(database.state.products[productId].inventory_quantity, 8);
  assert.equal(Object.keys(database.state.items).length, 1);
});

test('rejects malformed cart credentials and returns sanitized database errors', async (t) => {
  const database = createDatabase({ failOn: 'FROM app.customer_carts' });
  const baseUrl = await startServer(t, database.pool);

  const missingToken = await fetch(`${baseUrl}/api/v1/cart`);
  assert.equal(missingToken.status, 401);

  const malformedJson = await fetch(`${baseUrl}/api/v1/cart/items`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-cart-token': 'A'.repeat(43),
    },
    body: '{',
  });
  assert.equal(malformedJson.status, 400);

  const token = await createCart(baseUrl);
  const failedRead = await fetch(`${baseUrl}/api/v1/cart`, {
    headers: { 'x-cart-token': token },
  });
  assert.equal(failedRead.status, 500);
  assert.equal(
    JSON.stringify(await failedRead.json()).includes('private'),
    false,
  );
});
