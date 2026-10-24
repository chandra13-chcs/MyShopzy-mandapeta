const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');

const productId = '57a85a0c-7081-4eb7-9c13-4b9842216b54';
const otherProductId = '7512bb41-8bcb-4237-996e-eb54635b5b74';
const otherShopProductId = '7b579b9a-d128-40f2-8ee3-5c7018b69a2d';
const teaVariantId = '2f74a125-f7b7-4df5-bf8a-98cd183af04f';
const teaLargeVariantId = 'a8823f8f-f327-4fe4-87a1-9beabdb1a784';
const coffeeVariantId = '1d275bf2-4252-4c55-8d0c-64618790539e';
const breadVariantId = '457314e2-47ae-49dc-a24f-92b356bbf001';
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
        operating_details: { open: '00:00', close: '23:59' },
        timezone: 'Asia/Kolkata',
        product_status: 'active',
        shop_status: 'active',
        partner_status: 'approved',
        partner_type: 'local_store',
        category_code: 'staples',
        partner_commission_bps_override: null,
        category_commission_bps_override: null,
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
        operating_details: { open: '00:00', close: '23:59' },
        timezone: 'Asia/Kolkata',
        product_status: 'active',
        shop_status: 'active',
        partner_status: 'approved',
        partner_type: 'local_store',
        category_code: null,
        partner_commission_bps_override: null,
        category_commission_bps_override: null,
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
        operating_details: { open: '00:00', close: '23:59' },
        timezone: 'Asia/Kolkata',
        product_status: 'active',
        shop_status: 'active',
        partner_status: 'approved',
        partner_type: 'local_store',
        category_code: null,
        partner_commission_bps_override: null,
        category_commission_bps_override: null,
      },
    },
    variants: {
      [teaVariantId]: {
        id: teaVariantId,
        product_id: productId,
        shop_id: shopId,
        partner_id: partnerId,
        label: '500 g',
        unit: 'g',
        quantity: 500,
        price_minor: '1500',
        stock: 8,
        sku: 'TEA-500',
        is_available: true,
        sort_order: 0,
      },
      [teaLargeVariantId]: {
        id: teaLargeVariantId,
        product_id: productId,
        shop_id: shopId,
        partner_id: partnerId,
        label: '1 kg',
        unit: 'kg',
        quantity: 1,
        price_minor: '2500',
        stock: 4,
        sku: 'TEA-1KG',
        is_available: true,
        sort_order: 1,
      },
      [coffeeVariantId]: {
        id: coffeeVariantId,
        product_id: otherProductId,
        shop_id: shopId,
        partner_id: partnerId,
        label: '1 unit',
        unit: 'each',
        quantity: 1,
        price_minor: '2500',
        stock: null,
        sku: 'COFFEE-01',
        is_available: true,
        sort_order: 0,
      },
      [breadVariantId]: {
        id: breadVariantId,
        product_id: otherShopProductId,
        shop_id: otherShopId,
        partner_id: otherPartnerId,
        label: '1 unit',
        unit: 'each',
        quantity: 1,
        price_minor: '2000',
        stock: 6,
        sku: 'BREAD-01',
        is_available: true,
        sort_order: 0,
      },
    },
    orders: [],
    orderItems: [],
    outstandingMinor: '0',
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
    if (normalized.startsWith('SELECT id, product_id, shop_id, partner_id, label')) {
      const variant = state.variants[params[0]];
      const matches =
        variant &&
        variant.product_id === params[1] &&
        variant.shop_id === params[2] &&
        variant.partner_id === params[3];
      return { rows: matches ? [{ ...variant }] : [], rowCount: matches ? 1 : 0 };
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
        'SELECT quantity FROM app.customer_cart_items WHERE cart_id = $1 AND product_id = $2 AND variant_id = $3',
      )
    ) {
      const item = state.items[`${params[0]}:${params[1]}:${params[2]}`];
      return { rows: item ? [{ quantity: item.quantity }] : [], rowCount: item ? 1 : 0 };
    }
    if (normalized.startsWith('UPDATE app.customer_carts SET shop_id = $2')) {
      const [id, selectedShopId, selectedPartnerId] = params;
      state.carts[id].shop_id = selectedShopId;
      state.carts[id].partner_id = selectedPartnerId;
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('INSERT INTO app.customer_cart_items')) {
      const [
        cartId,
        selectedProductId,
        selectedVariantId,
        selectedShopId,
        selectedPartnerId,
        quantity,
      ] = params;
      state.items[`${cartId}:${selectedProductId}:${selectedVariantId}`] = {
        cart_id: cartId,
        product_id: selectedProductId,
        variant_id: selectedVariantId,
        shop_id: selectedShopId,
        partner_id: selectedPartnerId,
        quantity,
      };
      return { rows: [{ quantity }], rowCount: 1 };
    }
    if (normalized.startsWith('UPDATE app.customer_cart_items SET quantity')) {
      const [cartId, selectedProductId, quantity, selectedVariantId] = params;
      state.items[`${cartId}:${selectedProductId}:${selectedVariantId}`].quantity = quantity;
      return { rows: [{ quantity }], rowCount: 1 };
    }
    if (normalized.startsWith('DELETE FROM app.customer_cart_items WHERE cart_id = $1 AND product_id = $2 AND variant_id = $3')) {
      const [cartId, selectedProductId, selectedVariantId] = params;
      const key = `${cartId}:${selectedProductId}:${selectedVariantId}`;
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
    if (normalized.startsWith('SELECT ci.product_id, ci.variant_id, ci.quantity')) {
      const items = Object.values(state.items)
        .filter((item) => item.cart_id === params[0])
        .map((item) => ({
          ...item,
          ...state.products[item.product_id],
          variant_label: state.variants[item.variant_id].label,
          variant_unit: state.variants[item.variant_id].unit,
          variant_quantity: state.variants[item.variant_id].quantity,
          variant_sku: state.variants[item.variant_id].sku,
          price_minor: state.variants[item.variant_id].price_minor,
          variant_stock: state.variants[item.variant_id].stock,
          variant_is_available: state.variants[item.variant_id].is_available,
          product_is_available: state.products[item.product_id].is_available,
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
    if (normalized.startsWith('SELECT user_id FROM app.customers WHERE user_id = $1')) {
      return params[0] === customerId
        ? { rows: [{ user_id: customerId }], rowCount: 1 }
        : { rows: [], rowCount: 0 };
    }
    if (normalized.includes('FROM app.customer_ledger_entries')) {
      return { rows: [{ outstanding_minor: state.outstandingMinor }], rowCount: 1 };
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
    if (normalized.startsWith('UPDATE app.product_variants SET stock')) {
      const [selectedVariantId, quantity] = params;
      const variant = state.variants[selectedVariantId];
      if (variant.stock < quantity) {
        return { rows: [], rowCount: 0 };
      }
      variant.stock -= quantity;
      return { rows: [{ id: selectedVariantId }], rowCount: 1 };
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
    jsonRequest(
      'POST',
      { productId, variantId: teaVariantId, quantity: 2, priceMinor: 1 },
      token,
    ),
  );
  assert.equal(added.status, 400);

  const missingVariant = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, quantity: 2 }, token),
  );
  assert.equal(missingVariant.status, 400);

  const validAdd = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, variantId: teaVariantId, quantity: 2 }, token),
  );
  assert.equal(validAdd.status, 200);
  assert.deepEqual(await validAdd.json(), {
    data: { productId, variantId: teaVariantId, quantity: 2 },
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
          variantId: teaVariantId,
          variantLabel: '500 g',
          shopId,
          name: 'Tea',
          sku: 'TEA-500',
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
    `${baseUrl}/api/v1/cart/items/${productId}/${teaVariantId}`,
    jsonRequest('PATCH', { quantity: 3 }, token),
  );
  assert.equal(updated.status, 200);
  assert.deepEqual(await updated.json(), {
    data: { productId, variantId: teaVariantId, quantity: 3 },
  });

  const removed = await fetch(
    `${baseUrl}/api/v1/cart/items/${productId}/${teaVariantId}`,
    jsonRequest('DELETE', undefined, token),
  );
  assert.equal(removed.status, 204);

  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, variantId: teaVariantId }, token),
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
      jsonRequest('POST', { productId, variantId: teaVariantId, quantity }, token),
    );
    assert.equal(response.status, 400);
  }

  const inactive = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId: otherProductId, variantId: coffeeVariantId }, token),
  );
  assert.equal(inactive.status, 409);
  assert.equal((await inactive.json()).error.code, 'PRODUCT_UNAVAILABLE');

  const mismatchedVariant = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest(
      'POST',
      { productId, variantId: coffeeVariantId },
      token,
    ),
  );
  assert.equal(mismatchedVariant.status, 404);
  assert.equal((await mismatchedVariant.json()).error.code, 'VARIANT_NOT_FOUND');

  const added = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, variantId: teaVariantId }, token),
  );
  assert.equal(added.status, 200);

  const otherShop = await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest(
      'POST',
      { productId: otherShopProductId, variantId: breadVariantId },
      token,
    ),
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
    jsonRequest('POST', { productId, variantId: teaVariantId, quantity: 2 }, token),
  );
  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, variantId: teaLargeVariantId }, token),
  );
  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest(
      'POST',
      { productId: otherProductId, variantId: coffeeVariantId, quantity: 1 },
      token,
    ),
  );
  database.state.variants[teaVariantId].price_minor = '1750';
  database.state.variants[teaLargeVariantId].price_minor = '3000';

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
          variantId: coffeeVariantId,
          variantLabel: '1 unit',
          name: 'Coffee',
          quantity: 1,
          priceMinor: '2500',
          lineTotalMinor: '2500',
        },
        {
          productId,
          variantId: teaVariantId,
          variantLabel: '500 g',
          name: 'Tea',
          quantity: 2,
          priceMinor: '1750',
          lineTotalMinor: '3500',
        },
        {
          productId,
          variantId: teaLargeVariantId,
          variantLabel: '1 kg',
          name: 'Tea',
          quantity: 1,
          priceMinor: '3000',
          lineTotalMinor: '3000',
        },
      ],
      currency: 'INR',
      storeOpen: true,
      opensAt: '00:00',
      closesAt: '23:59',
      itemSubtotalMinor: '9000',
      deliveryFeeMinor: '0',
      discountMinor: '0',
      totalMinor: '9000',
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
  assert.equal(order.itemSubtotalMinor, '9000');
  assert.equal(order.deliveryFeeMinor, '0');
  assert.equal(order.discountMinor, '0');
  assert.equal(order.totalMinor, '9000');
  assert.equal(order.items, 3);

  const insertOrder = database.queries.find((query) =>
    query.sql.startsWith('INSERT INTO app.orders'),
  );
  assert.equal(insertOrder.params[1], customerId);
  assert.equal(insertOrder.params[5], '9000');
  assert.equal(insertOrder.params[8], '9000');
  assert.equal(insertOrder.params[10], '450');
  assert.match(insertOrder.sql, /payment_method/);
  assert.match(insertOrder.sql, /'cod'/);
  const teaSnapshot = database.state.orderItems.find(
    ({ params }) => params[4] === productId,
  );
  assert.equal(teaSnapshot.params[5], 'Tea');
  assert.equal(teaSnapshot.params[7], '1750');
  assert.equal(teaSnapshot.params[8], 2);
  assert.equal(teaSnapshot.params[9], '3500');
  assert.equal(teaSnapshot.params[10], 500);
  assert.equal(teaSnapshot.params[11], '175');
  assert.deepEqual(JSON.parse(teaSnapshot.params[13]), {
    variantId: teaVariantId,
    label: '500 g',
    unit: 'g',
    quantity: 500,
    sku: 'TEA-500',
    unitPriceMinor: '1750',
  });
  assert.equal(
    database.queries.filter((query) =>
      query.sql.startsWith('INSERT INTO app.order_items'),
    ).length,
    3,
  );
  assert.equal(database.state.variants[teaVariantId].stock, 6);
  assert.equal(database.state.variants[teaLargeVariantId].stock, 3);
  assert.equal(database.state.products[productId].inventory_quantity, 8);
  assert.equal(database.state.orders.length, 1);
  assert.equal(database.state.orderItems.length, 3);
  assert.equal(Object.keys(database.state.items).length, 0);
});

test('confirmed dues block quote and order placement until the balance is cleared', async (t) => {
  const database = createDatabase();
  database.state.outstandingMinor = '750';
  const baseUrl = await startServer(t, database.pool, { authenticated: true });
  const token = await createCart(baseUrl);
  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, variantId: teaVariantId }, token),
  );

  const quote = await fetch(
    `${baseUrl}/api/v1/checkout/quote`,
    jsonRequest('POST', {}, token),
  );
  assert.equal(quote.status, 409);
  assert.deepEqual((await quote.json()).error, {
    code: 'OUTSTANDING_DUES',
    message: 'Resolve outstanding delivery dues before placing another order.',
    details: { outstandingMinor: '750' },
  });

  const blockedOrder = await fetch(
    `${baseUrl}/api/v1/orders`,
    jsonRequest('POST', { deliveryAddress }, token),
  );
  assert.equal(blockedOrder.status, 409);
  assert.equal((await blockedOrder.json()).error.details.outstandingMinor, '750');
  assert.equal(database.state.orders.length, 0);

  database.state.outstandingMinor = '0';
  const paidOrder = await fetch(
    `${baseUrl}/api/v1/orders`,
    jsonRequest('POST', { deliveryAddress }, token),
  );
  assert.equal(paidOrder.status, 201);
  assert.equal(database.state.orders.length, 1);
});

test('applies category-code commission rates and snapshots item commissions in one order', async (t) => {
  const database = createDatabase();
  database.state.products[otherProductId].category_code = 'frozen_foods';
  database.state.variants[teaVariantId].price_minor = '50000';
  database.state.variants[coffeeVariantId].price_minor = '50000';
  const baseUrl = await startServer(t, database.pool, { authenticated: true });
  const token = await createCart(baseUrl);
  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, variantId: teaVariantId, quantity: 1 }, token),
  );
  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId: otherProductId, variantId: coffeeVariantId, quantity: 1 }, token),
  );

  const response = await fetch(
    `${baseUrl}/api/v1/orders`,
    jsonRequest('POST', { deliveryAddress }, token),
  );
  assert.equal(response.status, 201);
  assert.equal(database.state.orders[0].params[5], '100000');
  assert.equal(database.state.orders[0].params[10], '7500');
  assert.match(
    database.queries.find(({ sql }) => sql.startsWith('SELECT ci.product_id')).sql,
    /category\.category_code/,
  );
  const stapleItem = database.state.orderItems.find(({ params }) => params[4] === productId);
  const frozenItem = database.state.orderItems.find(({ params }) => params[4] === otherProductId);
  assert.equal(stapleItem.params[10], 500);
  assert.equal(stapleItem.params[11], '2500');
  assert.equal(frozenItem.params[10], 1000);
  assert.equal(frozenItem.params[11], '5000');
});

test('rejects order placement while closed and leaves cart mutations available', async (t) => {
  const database = createDatabase();
  database.state.products[productId].operating_details = {
    open: '00:00',
    close: '00:00',
  };
  const baseUrl = await startServer(t, database.pool, { authenticated: true });
  const token = await createCart(baseUrl);
  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, variantId: teaVariantId }, token),
  );

  const quote = await fetch(
    `${baseUrl}/api/v1/checkout/quote`,
    jsonRequest('POST', {}, token),
  );
  assert.equal(quote.status, 200);
  assert.equal((await quote.json()).data.storeOpen, false);

  const updated = await fetch(
    `${baseUrl}/api/v1/cart/items/${productId}/${teaVariantId}`,
    jsonRequest('PATCH', { quantity: 2 }, token),
  );
  assert.equal(updated.status, 200);
  const removed = await fetch(
    `${baseUrl}/api/v1/cart/items/${productId}/${teaVariantId}`,
    jsonRequest('DELETE', undefined, token),
  );
  assert.equal(removed.status, 204);

  await fetch(
    `${baseUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, variantId: teaVariantId }, token),
  );
  const response = await fetch(
    `${baseUrl}/api/v1/orders`,
    jsonRequest('POST', { deliveryAddress }, token),
  );

  assert.equal(response.status, 409);
  assert.deepEqual((await response.json()).error, {
    code: 'STORE_CLOSED',
    message: 'Orders are accepted between 7:00 AM and 11:00 PM',
  });
  assert.equal(database.state.orders.length, 0);
});

test('rejects cross-shop checkout, unavailable checkout products, and unauthenticated orders', async (t) => {
  const database = createDatabase();
  const publicUrl = await startServer(t, database.pool);
  const authenticatedUrl = await startServer(t, database.pool, { authenticated: true });
  const token = await createCart(publicUrl);
  await fetch(
    `${publicUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, variantId: teaVariantId }, token),
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
    `${authenticatedUrl}/api/v1/checkout/quote`,
    jsonRequest('POST', {}, token),
  );
  assert.equal(unavailable.status, 409);
  assert.equal((await unavailable.json()).error.code, 'CART_ITEM_UNAVAILABLE');

  const separateCart = await createCart(publicUrl);
  const firstShop = await fetch(
    `${publicUrl}/api/v1/cart/items`,
    jsonRequest(
      'POST',
      { productId: otherShopProductId, variantId: breadVariantId },
      separateCart,
    ),
  );
  assert.equal(firstShop.status, 200);
  const crossShopAdd = await fetch(
    `${publicUrl}/api/v1/cart/items`,
    jsonRequest('POST', { productId, variantId: teaVariantId }, separateCart),
  );
  assert.equal(crossShopAdd.status, 409);

  const separateCartId = Object.values(database.state.carts).find(
    (cart) => cart.shop_id === otherShopId,
  ).id;
  database.state.items[`${separateCartId}:${productId}:${teaVariantId}`] = {
    cart_id: separateCartId,
    product_id: productId,
    variant_id: teaVariantId,
    shop_id: shopId,
    partner_id: partnerId,
    quantity: 1,
  };
  const corruptCheckout = await fetch(
    `${authenticatedUrl}/api/v1/checkout/quote`,
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
    jsonRequest('POST', { productId, variantId: teaVariantId, quantity: 2 }, token),
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
  assert.equal(database.state.variants[teaVariantId].stock, 8);
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
