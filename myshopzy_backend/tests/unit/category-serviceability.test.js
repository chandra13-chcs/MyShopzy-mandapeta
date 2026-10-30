'use strict';

const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const { createApp } = require('../../src/app');
const {
  CATEGORY_DELIVERY_LIMITS_METERS,
  MANDAPETA_BUS_STAND,
  assessCategoryServiceability,
  deliveryCategoryForPartnerType,
} = require('../../src/modules/delivery-serviceability/categories');

async function startServer(t, options = {}) {
  const server = http.createServer(
    createApp({ logger: { error() {} }, ...options }),
  );
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  return `http://127.0.0.1:${server.address().port}`;
}

for (const [category, maximumDistanceMeters] of Object.entries(
  CATEGORY_DELIVERY_LIMITS_METERS,
)) {
  test(`${category} is serviceable at its limit and blocked beyond it`, () => {
    assert.equal(
      assessCategoryServiceability(category, maximumDistanceMeters)
        .isDeliverable,
      true,
    );
    const outside = assessCategoryServiceability(
      category,
      maximumDistanceMeters + 1,
    );
    assert.equal(outside.isDeliverable, false);
    assert.equal(outside.maximumDistanceMeters, maximumDistanceMeters);
    assert.match(outside.message, new RegExp(`${maximumDistanceMeters / 1000} km`));
  });
}

test('maps persisted partner types to their customer delivery categories', () => {
  assert.equal(deliveryCategoryForPartnerType('local_store'), 'grocery');
  assert.equal(deliveryCategoryForPartnerType('meat'), 'meat');
  assert.equal(
    deliveryCategoryForPartnerType('fruits_vegetables'),
    'vegetables_fruits',
  );
  assert.equal(deliveryCategoryForPartnerType('bakery'), 'bakery');
  assert.equal(deliveryCategoryForPartnerType('restaurant'), 'restaurant');
  assert.equal(deliveryCategoryForPartnerType('other'), null);
});

test('routes from Mandapeta Bus Stand and reuses a valid route across categories', async (t) => {
  let routingCalls = 0;
  const baseUrl = await startServer(t, {
    deliveryDistanceClient: {
      async getRoadDistanceMetres(origin, destination) {
        routingCalls++;
        assert.deepEqual(origin, MANDAPETA_BUS_STAND);
        assert.deepEqual(destination, {
          latitude: 16.9,
          longitude: 81.95,
        });
        return 9999;
      },
    },
  });

  for (const category of ['grocery', 'meat']) {
    const response = await fetch(
      `${baseUrl}/api/v1/delivery/category-serviceability`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          category,
          latitude: 16.9,
          longitude: 81.95,
        }),
      },
    );
    assert.equal(response.status, 200);
    const { data } = await response.json();
    assert.equal(data.distanceMeters, 9999);
    assert.equal(data.isDeliverable, true);
    assert.equal(data.maximumDistanceMeters, 10000);
  }
  assert.equal(routingCalls, 1);
});

test('fails closed when route calculation is unavailable', async (t) => {
  const baseUrl = await startServer(t, {
    deliveryDistanceClient: {
      async getRoadDistanceMetres() {
        throw new Error('routing failure');
      },
    },
  });
  const response = await fetch(
    `${baseUrl}/api/v1/delivery/category-serviceability`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        category: 'restaurant',
        latitude: 16.9,
        longitude: 81.95,
      }),
    },
  );
  assert.equal(response.status, 503);
  assert.equal((await response.json()).error.code, 'ROUTING_UNAVAILABLE');
});

test('rejects invalid category and coordinates without routing', async (t) => {
  const baseUrl = await startServer(t, {
    deliveryDistanceClient: {
      async getRoadDistanceMetres() {
        assert.fail('Invalid destinations must not be routed.');
      },
    },
  });
  for (const body of [
    { category: 'unknown', latitude: 16.9, longitude: 81.95 },
    { category: 'parcel', latitude: 91, longitude: 81.95 },
  ]) {
    const response = await fetch(
      `${baseUrl}/api/v1/delivery/category-serviceability`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body),
      },
    );
    assert.equal(response.status, 400);
  }
});
