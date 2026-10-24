const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');

const customerId = '27dcad4a-f166-4fc8-a224-3d1c099dd459';
const otherCustomerId = '69303022-f984-4acd-8258-bb48dfd4a94b';
const addressId = '5ea58bd2-e598-47bf-b6d7-8307ea22951a';
const orderId = 'd1ca6b39-b9d9-423b-b93b-3e513f232d9a';
const otherOrderId = 'ad262355-e3df-4534-8fe1-d78d4387f282';
const productId = '57a85a0c-7081-4eb7-9c13-4b9842216b54';
const parcelId = '3acdf0f1-7877-4d28-8207-59360158c1ce';
const address = { formattedAddress: '12 Green Park Road, Mandapeta' };

function createDatabase({
  failOn,
  serverNow = '2026-10-11T06:00:30.000Z',
  placedAt = '2026-10-11T06:00:00.000Z',
} = {}) {
  const profile = {
    id: customerId,
    display_name: 'Chandra Shekar',
    email: 'chandra@example.test',
    phone: '+918900000001',
    created_at: '2026-10-01T00:00:00.000Z',
  };
  const addresses = new Map();
  const wishlist = new Set();
  const parcels = new Map();
  const queries = [];
  const orders = new Map([
    [
      orderId,
      {
        id: orderId,
        customer_user_id: customerId,
        status: 'placed',
        placed_at: placedAt,
        total_minor: '3000',
        delivery_address_snapshot: address,
      },
    ],
    [
      otherOrderId,
      {
        id: otherOrderId,
        customer_user_id: otherCustomerId,
        status: 'delivered',
        total_minor: '5000',
        delivery_address_snapshot: { formattedAddress: 'Private address' },
      },
    ],
  ]);

  async function query(sql, params = []) {
    const normalized = sql.replace(/\s+/g, ' ').trim();
    queries.push({ sql: normalized, params });
    if (failOn && normalized.includes(failOn)) {
      throw new Error('private database diagnostic');
    }

    if (normalized.startsWith('SELECT u.id, u.display_name')) {
      return { rows: [profile], rowCount: 1 };
    }
    if (normalized.startsWith("UPDATE app.orders AS o SET status = 'cancelled'")) {
      const [selectedOrderId, ownerId, reason] = params;
      const order = orders.get(selectedOrderId);
      const eligibleStatuses = ['placed', 'confirmed', 'preparing'];
      const stillInWindow =
        order &&
        new Date(order.placed_at).getTime() + 120_000 >
          new Date(serverNow).getTime();
      if (
        !order ||
        order.customer_user_id !== ownerId ||
        !eligibleStatuses.includes(order.status) ||
        !stillInWindow
      ) {
        return { rows: [], rowCount: 0 };
      }
      order.status = 'cancelled';
      order.cancellation_reason = reason;
      return {
        rows: [
          {
            id: order.id,
            status: order.status,
            cancellation_reason: reason,
            placed_at: order.placed_at,
            cancellation_deadline_at: new Date(
              new Date(order.placed_at).getTime() + 120_000,
            ).toISOString(),
            server_now: serverNow,
            cancellation_eligible: false,
          },
        ],
        rowCount: 1,
      };
    }
    if (
      normalized.startsWith(
        'SELECT o.status, o.placed_at, clock_timestamp() AS server_now',
      )
    ) {
      const [selectedOrderId, ownerId] = params;
      const order = orders.get(selectedOrderId);
      return order && order.customer_user_id === ownerId
        ? {
            rows: [
              {
                status: order.status,
                placed_at: order.placed_at,
                server_now: serverNow,
              },
            ],
            rowCount: 1,
          }
        : { rows: [], rowCount: 0 };
    }
    if (normalized.startsWith('UPDATE app.users AS u')) {
      const [, displayName, hasEmail, email, hasPhone, phone] = params;
      const nextEmail = hasEmail ? email : profile.email;
      const nextPhone = hasPhone ? phone : profile.phone;
      if (nextEmail === null && nextPhone === null) {
        return { rows: [], rowCount: 0 };
      }
      profile.display_name = displayName ?? profile.display_name;
      if (hasEmail) profile.email = email;
      if (hasPhone) profile.phone = phone;
      return { rows: [profile], rowCount: 1 };
    }
    if (normalized.startsWith('SELECT u.email, u.phone')) {
      return {
        rows: [{ email: profile.email, phone: profile.phone }],
        rowCount: 1,
      };
    }
    if (normalized.startsWith('SELECT a.id, a.label, a.address_snapshot')) {
      return {
        rows: [...addresses.values()].filter(
          (savedAddress) => savedAddress.customer_user_id === params[0],
        ),
        rowCount: addresses.size,
      };
    }
    if (normalized.startsWith('INSERT INTO app.customer_saved_addresses')) {
      const [id, ownerId, label, snapshot] = params;
      const savedAddress = {
        id,
        customer_user_id: ownerId,
        label,
        address_snapshot: JSON.parse(snapshot),
      };
      addresses.set(id, savedAddress);
      return { rows: [savedAddress], rowCount: 1 };
    }
    if (normalized.startsWith('UPDATE app.customer_saved_addresses AS a')) {
      const [id, ownerId, label, snapshot] = params;
      const existing = addresses.get(id);
      if (!existing || existing.customer_user_id !== ownerId) {
        return { rows: [], rowCount: 0 };
      }
      existing.label = label ?? existing.label;
      existing.address_snapshot = snapshot
        ? JSON.parse(snapshot)
        : existing.address_snapshot;
      return { rows: [existing], rowCount: 1 };
    }
    if (normalized.startsWith('DELETE FROM app.customer_saved_addresses AS a')) {
      const [id, ownerId] = params;
      const existing = addresses.get(id);
      if (!existing || existing.customer_user_id !== ownerId) {
        return { rows: [], rowCount: 0 };
      }
      addresses.delete(id);
      return { rows: [{ id }], rowCount: 1 };
    }
    if (normalized.startsWith('SELECT wi.product_id')) {
      return {
        rows: [...wishlist].map((savedProductId) => ({
          product_id: savedProductId,
          name: 'Tea',
          price_minor: '1500',
          currency: 'INR',
          available: true,
        })),
        rowCount: wishlist.size,
      };
    }
    if (normalized.startsWith('INSERT INTO app.customer_wishlist_items')) {
      const [ownerId, selectedProductId] = params;
      if (ownerId !== customerId) return { rows: [], rowCount: 0 };
      const wasSaved = wishlist.has(selectedProductId);
      wishlist.add(selectedProductId);
      return {
        rows: wasSaved ? [] : [{ product_id: selectedProductId }],
        rowCount: wasSaved ? 0 : 1,
      };
    }
    if (normalized.startsWith('SELECT 1 FROM app.customers AS c')) {
      return params[0] === customerId
        ? { rows: [{ '?column?': 1 }], rowCount: 1 }
        : { rows: [], rowCount: 0 };
    }
    if (normalized.startsWith('SELECT 1 FROM app.customer_wishlist_items')) {
      return wishlist.has(params[1])
        ? { rows: [{ '?column?': 1 }], rowCount: 1 }
        : { rows: [], rowCount: 0 };
    }
    if (normalized.startsWith('DELETE FROM app.customer_wishlist_items AS wi')) {
      if (params[0] === customerId) wishlist.delete(params[1]);
      return { rows: [], rowCount: 1 };
    }
    if (normalized.startsWith('SELECT o.id, o.partner_id, o.shop_id')) {
      const isDetailQuery = normalized.includes('delivery_address_snapshot');
      if (isDetailQuery) {
        const [selectedOrderId, ownerId] = params;
        const order = orders.get(selectedOrderId);
        return {
          rows:
            order && order.customer_user_id === ownerId
              ? [{ ...order, shop_name: 'Mandapeta Shop' }]
              : [],
          rowCount: order && order.customer_user_id === ownerId ? 1 : 0,
        };
      }
      const [ownerId] = params;
      const result = [...orders.values()]
        .filter((order) => order.customer_user_id === ownerId)
        .map((order) => ({ ...order, item_count: 1, shop_name: 'Mandapeta Shop' }));
      return { rows: result, rowCount: result.length };
    }
    if (normalized.startsWith('SELECT product_id, product_name_snapshot')) {
      return {
        rows: [{ product_id: productId, product_name_snapshot: 'Tea', quantity: 2 }],
        rowCount: 1,
      };
    }
    if (normalized.startsWith('SELECT id, pickup_location, drop_location')) {
      const detail = normalized.includes('WHERE id = $1 AND customer_user_id = $2');
      if (detail) {
        const parcel = parcels.get(params[0]);
        return {
          rows: parcel && parcel.customer_user_id === params[1] ? [parcel] : [],
          rowCount: parcel && parcel.customer_user_id === params[1] ? 1 : 0,
        };
      }
      const rows = [...parcels.values()].filter(
        (parcel) => parcel.customer_user_id === params[0],
      );
      return { rows, rowCount: rows.length };
    }
    if (normalized.startsWith('INSERT INTO app.parcel_bookings')) {
      const [id, ownerId, pickup, drop, type, weight, instructions] = params;
      if (ownerId !== customerId) return { rows: [], rowCount: 0 };
      const parcel = {
        id,
        customer_user_id: ownerId,
        pickup_location: pickup,
        drop_location: drop,
        parcel_type: type,
        weight_grams: weight,
        instructions,
        status: 'requested',
      };
      parcels.set(id, parcel);
      return { rows: [parcel], rowCount: 1 };
    }

    assert.fail(`Unexpected customer-account SQL in test double: ${normalized}`);
  }

  return {
    pool: { query },
    queries,
    profile,
    addresses,
    wishlist,
    parcels,
    orders,
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
    createApp({ databasePool, authenticateCustomer }),
  );
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

function jsonRequest(method, body) {
  return {
    method,
    headers: { 'content-type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  };
}

test('requires trusted authentication on every private customer resource', async (t) => {
  const database = createDatabase();
  const baseUrl = await startServer(t, database.pool);
  const requests = [
    ['GET', '/api/v1/me/profile'],
    ['PATCH', '/api/v1/me/profile'],
    ['GET', '/api/v1/me/addresses'],
    ['POST', '/api/v1/me/addresses'],
    ['PATCH', `/api/v1/me/addresses/${addressId}`],
    ['DELETE', `/api/v1/me/addresses/${addressId}`],
    ['GET', '/api/v1/me/wishlist'],
    ['POST', '/api/v1/me/wishlist/items'],
    ['DELETE', `/api/v1/me/wishlist/items/${productId}`],
    ['GET', '/api/v1/me/orders'],
    ['GET', `/api/v1/me/orders/${orderId}`],
    ['POST', `/api/v1/me/orders/${orderId}/cancel`],
    ['GET', '/api/v1/me/parcels'],
    ['POST', '/api/v1/me/parcels'],
    ['GET', `/api/v1/me/parcels/${parcelId}`],
  ];

  for (const [method, path] of requests) {
    const response = await fetch(
      `${baseUrl}${path}`,
      jsonRequest(method, method === 'GET' || method === 'DELETE' ? undefined : {}),
    );
    assert.equal(response.status, 401, `${method} ${path}`);
    assert.deepEqual(await response.json(), {
      error: {
        code: 'AUTHENTICATION_REQUIRED',
        message: 'Customer authentication is required.',
      },
    });
  }
  assert.equal(database.queries.length, 0);
});

test('reads and updates the authenticated customer profile only', async (t) => {
  const database = createDatabase();
  const baseUrl = await startServer(t, database.pool, { authenticated: true });

  const read = await fetch(`${baseUrl}/api/v1/me/profile`);
  assert.equal(read.status, 200);
  assert.equal((await read.json()).data.id, customerId);

  const update = await fetch(
    `${baseUrl}/api/v1/me/profile`,
    jsonRequest('PATCH', {
      displayName: 'Chandra S',
      email: null,
    }),
  );
  assert.equal(update.status, 200);
  assert.deepEqual((await update.json()).data, {
    ...database.profile,
    display_name: 'Chandra S',
    email: null,
  });

  const updateQuery = database.queries.find((query) =>
    query.sql.startsWith('UPDATE app.users'),
  );
  assert.equal(updateQuery.params[0], customerId);
  assert.match(updateQuery.sql, /u\.id = \$1/);

  const forgedIdentity = await fetch(
    `${baseUrl}/api/v1/me/profile`,
    jsonRequest('PATCH', {
      displayName: 'Not the authenticated identity',
      customerUserId: otherCustomerId,
    }),
  );
  assert.equal(forgedIdentity.status, 400);

  const invalid = await fetch(
    `${baseUrl}/api/v1/me/profile`,
    jsonRequest('PATCH', { displayName: '  ' }),
  );
  assert.equal(invalid.status, 400);
  assert.equal(database.profile.display_name, 'Chandra S');

  const invalidClear = await fetch(
    `${baseUrl}/api/v1/me/profile`,
    jsonRequest('PATCH', { phone: null }),
  );
  assert.equal(invalidClear.status, 400);
});

test('cancels eligible customer orders before the strict two-minute boundary', async (t) => {
  const database = createDatabase({
    serverNow: '2026-10-11T06:01:59.999Z',
  });
  const baseUrl = await startServer(t, database.pool, { authenticated: true });
  const response = await fetch(
    `${baseUrl}/api/v1/me/orders/${orderId}/cancel`,
    jsonRequest('POST', { reason: 'Changed my mind' }),
  );

  assert.equal(response.status, 200);
  assert.equal((await response.json()).data.status, 'cancelled');
  assert.equal(database.queries[0].params[2], 'Changed my mind');
  assert.equal(database.orders.get(orderId).cancellation_reason, 'Changed my mind');
  assert.match(database.queries[0].sql, /clock_timestamp\(\)/);
  assert.match(database.queries[0].sql, /interval '2 minutes'/);

  const duplicate = await fetch(
    `${baseUrl}/api/v1/me/orders/${orderId}/cancel`,
    jsonRequest('POST', { reason: 'Changed my mind' }),
  );
  assert.equal(duplicate.status, 409);
  assert.equal((await duplicate.json()).error.code, 'ORDER_NOT_CANCELLABLE');
});

test('rejects cancellation at and after the two-minute boundary', async (t) => {
  const database = createDatabase({
    serverNow: '2026-10-11T06:02:00.001Z',
  });
  const baseUrl = await startServer(t, database.pool, { authenticated: true });
  const response = await fetch(
    `${baseUrl}/api/v1/me/orders/${orderId}/cancel`,
    jsonRequest('POST', { reason: 'Changed my mind' }),
  );

  assert.equal(response.status, 409);
  assert.equal((await response.json()).error.code, 'CANCELLATION_WINDOW_CLOSED');
  assert.equal(database.orders.get(orderId).status, 'placed');
});

test('does not cancel orders in incompatible states or accept invalid reasons', async (t) => {
  const database = createDatabase({
    serverNow: '2026-10-11T06:01:00.000Z',
  });
  database.orders.get(orderId).status = 'picked_up';
  const baseUrl = await startServer(t, database.pool, { authenticated: true });

  const invalidReason = await fetch(
    `${baseUrl}/api/v1/me/orders/${orderId}/cancel`,
    jsonRequest('POST', { reason: '  ' }),
  );
  assert.equal(invalidReason.status, 400);

  const incompatible = await fetch(
    `${baseUrl}/api/v1/me/orders/${orderId}/cancel`,
    jsonRequest('POST', { reason: 'Changed my mind' }),
  );
  assert.equal(incompatible.status, 409);
  assert.equal((await incompatible.json()).error.code, 'ORDER_NOT_CANCELLABLE');
  assert.equal(database.orders.get(orderId).status, 'picked_up');
});

test('creates, lists, updates, and deletes customer-owned saved addresses', async (t) => {
  const database = createDatabase();
  const baseUrl = await startServer(t, database.pool, { authenticated: true });

  const create = await fetch(
    `${baseUrl}/api/v1/me/addresses`,
    jsonRequest('POST', { label: 'Home', address }),
  );
  assert.equal(create.status, 201);
  const created = (await create.json()).data;
  assert.equal(created.label, 'Home');
  assert.deepEqual(created.address_snapshot, address);

  const list = await fetch(`${baseUrl}/api/v1/me/addresses`);
  assert.equal(list.status, 200);
  assert.equal((await list.json()).data.length, 1);

  const update = await fetch(
    `${baseUrl}/api/v1/me/addresses/${created.id}`,
    jsonRequest('PATCH', {
      label: 'Work',
      address: { formattedAddress: '24 Market Street, Mandapeta' },
    }),
  );
  assert.equal(update.status, 200);
  assert.equal((await update.json()).data.label, 'Work');
  const updateQuery = database.queries.find((query) =>
    query.sql.startsWith('UPDATE app.customer_saved_addresses'),
  );
  assert.equal(updateQuery.params[1], customerId);
  assert.match(updateQuery.sql, /a\.customer_user_id = \$2/);

  const invalid = await fetch(
    `${baseUrl}/api/v1/me/addresses`,
    jsonRequest('POST', { label: '', address: {} }),
  );
  assert.equal(invalid.status, 400);

  const invalidPath = await fetch(
    `${baseUrl}/api/v1/me/addresses/not-a-uuid`,
    jsonRequest('PATCH', { label: 'Other' }),
  );
  assert.equal(invalidPath.status, 400);

  const wrongOwner = await fetch(
    `${baseUrl}/api/v1/me/addresses/${addressId}`,
    jsonRequest('PATCH', { label: 'Private' }),
  );
  assert.equal(wrongOwner.status, 404);

  const remove = await fetch(
    `${baseUrl}/api/v1/me/addresses/${created.id}`,
    jsonRequest('DELETE'),
  );
  assert.equal(remove.status, 204);
  assert.equal(database.addresses.size, 0);
});

test('adds, lists, and removes products in the authenticated wishlist', async (t) => {
  const database = createDatabase();
  const baseUrl = await startServer(t, database.pool, { authenticated: true });

  const add = await fetch(
    `${baseUrl}/api/v1/me/wishlist/items`,
    jsonRequest('POST', { productId }),
  );
  assert.equal(add.status, 201);
  assert.deepEqual(await add.json(), {
    data: { productId, saved: true },
  });
  const addQuery = database.queries.find((query) =>
    query.sql.startsWith('INSERT INTO app.customer_wishlist_items'),
  );
  assert.equal(addQuery.params[0], customerId);

  const list = await fetch(`${baseUrl}/api/v1/me/wishlist`);
  assert.equal(list.status, 200);
  assert.equal((await list.json()).data[0].product_id, productId);

  const invalid = await fetch(
    `${baseUrl}/api/v1/me/wishlist/items`,
    jsonRequest('POST', { productId: 'demo-product-id' }),
  );
  assert.equal(invalid.status, 400);

  const remove = await fetch(
    `${baseUrl}/api/v1/me/wishlist/items/${productId}`,
    jsonRequest('DELETE'),
  );
  assert.equal(remove.status, 204);
  assert.equal(database.wishlist.size, 0);
});

test('lists and reads only the authenticated customer orders', async (t) => {
  const database = createDatabase();
  const baseUrl = await startServer(t, database.pool, { authenticated: true });

  const list = await fetch(`${baseUrl}/api/v1/me/orders?limit=5&offset=0`);
  assert.equal(list.status, 200);
  const listBody = await list.json();
  assert.deepEqual(listBody.pagination, { limit: 5, offset: 0 });
  assert.deepEqual(listBody.data.map((order) => order.id), [orderId]);
  const listQuery = database.queries.find((query) =>
    query.sql.startsWith('SELECT o.id, o.partner_id, o.shop_id'),
  );
  assert.equal(listQuery.params[0], customerId);

  const detail = await fetch(`${baseUrl}/api/v1/me/orders/${orderId}`);
  assert.equal(detail.status, 200);
  const detailBody = (await detail.json()).data;
  assert.equal(detailBody.id, orderId);
  assert.equal(detailBody.items[0].product_id, productId);
  const detailQuery = database.queries.find((query) =>
    query.sql.includes('delivery_address_snapshot'),
  );
  assert.deepEqual(detailQuery.params, [orderId, customerId]);

  const anotherCustomersOrder = await fetch(
    `${baseUrl}/api/v1/me/orders/${otherOrderId}`,
  );
  assert.equal(anotherCustomersOrder.status, 404);
  assert.equal((await anotherCustomersOrder.json()).error.code, 'ORDER_NOT_FOUND');

  const invalid = await fetch(`${baseUrl}/api/v1/me/orders?limit=101`);
  assert.equal(invalid.status, 400);
});

test('creates and reads parcel bookings with validated UI-supported fields', async (t) => {
  const database = createDatabase();
  const baseUrl = await startServer(t, database.pool, { authenticated: true });
  const payload = {
    pickupLocation: '12 Green Park Road',
    dropLocation: '24 Market Street',
    parcelType: 'Documents',
    weightKg: 1.25,
    instructions: 'Call on arrival',
  };

  const create = await fetch(
    `${baseUrl}/api/v1/me/parcels`,
    jsonRequest('POST', payload),
  );
  assert.equal(create.status, 201);
  const parcel = (await create.json()).data;
  assert.equal(parcel.parcel_type, 'Documents');
  assert.equal(parcel.weight_grams, 1250);
  assert.equal(parcel.status, 'requested');
  const insertQuery = database.queries.find((query) =>
    query.sql.startsWith('INSERT INTO app.parcel_bookings'),
  );
  assert.equal(insertQuery.params[1], customerId);

  const invalidWeight = await fetch(
    `${baseUrl}/api/v1/me/parcels`,
    jsonRequest('POST', { ...payload, weightKg: 20.1 }),
  );
  assert.equal(invalidWeight.status, 400);
  const invalidType = await fetch(
    `${baseUrl}/api/v1/me/parcels`,
    jsonRequest('POST', { ...payload, parcelType: 'Same day' }),
  );
  assert.equal(invalidType.status, 400);

  const list = await fetch(`${baseUrl}/api/v1/me/parcels`);
  assert.equal(list.status, 200);
  assert.equal((await list.json()).data.length, 1);

  const detail = await fetch(`${baseUrl}/api/v1/me/parcels/${parcel.id}`);
  assert.equal(detail.status, 200);
  assert.equal((await detail.json()).data.id, parcel.id);

  const otherId = await fetch(`${baseUrl}/api/v1/me/parcels/${parcelId}`);
  assert.equal(otherId.status, 404);
});

test('sanitizes database failures for profile, address, order, wishlist, and parcel APIs', async (t) => {
  const endpoints = [
    ['GET', '/api/v1/me/profile', 'FROM app.users AS u'],
    ['GET', '/api/v1/me/addresses', 'FROM app.customer_saved_addresses AS a'],
    ['GET', '/api/v1/me/wishlist', 'FROM app.customer_wishlist_items AS wi'],
    ['GET', '/api/v1/me/orders', 'FROM app.orders AS o'],
    ['GET', '/api/v1/me/parcels', 'FROM app.parcel_bookings'],
  ];
  for (const [method, path, failOn] of endpoints) {
    const database = createDatabase({ failOn });
    const baseUrl = await startServer(t, database.pool, { authenticated: true });
    const response = await fetch(`${baseUrl}${path}`, jsonRequest(method));
    assert.equal(response.status, 500);
    assert.equal(
      JSON.stringify(await response.json()).includes('private'),
      false,
    );
  }
});
