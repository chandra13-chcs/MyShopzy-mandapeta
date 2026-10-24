const assert = require('node:assert/strict');
const test = require('node:test');

const {
  calculateDeliveryPricing,
  FREE_DELIVERY_THRESHOLD_MINOR,
  MAX_DELIVERY_DISTANCE_METERS,
  PLATFORM_FEE_MINOR,
} = require('../../src/modules/delivery-serviceability/pricing');

test('uses the flat fee through 4 km and exact metre-based pricing above 4 km', () => {
  assert.equal(
    calculateDeliveryPricing({
      merchandiseSubtotalMinor: 49899,
      distanceMeters: 4000,
    }).deliveryFeeMinor,
    3000,
  );
  assert.equal(
    calculateDeliveryPricing({
      merchandiseSubtotalMinor: 49899,
      distanceMeters: 4001,
    }).deliveryFeeMinor,
    2401,
  );
  assert.equal(
    calculateDeliveryPricing({
      merchandiseSubtotalMinor: 49899,
      distanceMeters: 4010,
    }).deliveryFeeMinor,
    2406,
  );
  assert.equal(
    calculateDeliveryPricing({
      merchandiseSubtotalMinor: 49899,
      distanceMeters: 5000,
    }).deliveryFeeMinor,
    3000,
  );
});

test('allows 18 km and rejects any greater distance', () => {
  const atLimit = calculateDeliveryPricing({
    merchandiseSubtotalMinor: 0,
    distanceMeters: 18000,
  });
  assert.equal(atLimit.deliverable, true);
  assert.equal(atLimit.deliveryFeeMinor, 10800);
  assert.equal(atLimit.platformFeeMinor, 1000);

  const outsideLimit = calculateDeliveryPricing({
    merchandiseSubtotalMinor: 0,
    distanceMeters: 18001,
  });
  assert.deepEqual(outsideLimit, {
    deliverable: false,
    reason: 'OUTSIDE_DELIVERY_RANGE',
    merchandiseSubtotalMinor: 0,
    distanceMeters: 18001,
    deliveryFeeMinor: null,
    platformFeeMinor: null,
    totalMinor: null,
  });
});

test('unlocks free delivery at 49900 paise but not 49899 paise', () => {
  const belowThreshold = calculateDeliveryPricing({
    merchandiseSubtotalMinor: 49899,
    distanceMeters: 5000,
  });
  const atThreshold = calculateDeliveryPricing({
    merchandiseSubtotalMinor: 49900,
    distanceMeters: 5000,
  });

  assert.equal(FREE_DELIVERY_THRESHOLD_MINOR, 49900);
  assert.equal(belowThreshold.deliveryFeeMinor, 3000);
  assert.equal(atThreshold.deliveryFeeMinor, 0);
  assert.equal(atThreshold.platformFeeMinor, PLATFORM_FEE_MINOR);
  assert.equal(atThreshold.totalMinor, 50900);
});

test('adds the platform fee once and keeps merchandise subtotal distinct', () => {
  const result = calculateDeliveryPricing({
    merchandiseSubtotalMinor: 20000,
    distanceMeters: 4000,
  });

  assert.equal(result.merchandiseSubtotalMinor, 20000);
  assert.equal(result.deliveryFeeMinor, 3000);
  assert.equal(result.platformFeeMinor, 1000);
  assert.equal(result.totalMinor, 24000);
  assert.equal(result.totalMinor, result.merchandiseSubtotalMinor +
    result.deliveryFeeMinor + result.platformFeeMinor);
});

test('validates subtotal and distance as non-negative safe integers', () => {
  for (const input of [
    { merchandiseSubtotalMinor: -1, distanceMeters: 1000 },
    { merchandiseSubtotalMinor: 1.5, distanceMeters: 1000 },
    { merchandiseSubtotalMinor: Number.MAX_SAFE_INTEGER + 1, distanceMeters: 1000 },
    { merchandiseSubtotalMinor: 1, distanceMeters: -1 },
    { merchandiseSubtotalMinor: 1, distanceMeters: 1000.5 },
    { merchandiseSubtotalMinor: 1, distanceMeters: Number.MAX_SAFE_INTEGER + 1 },
  ]) {
    assert.throws(() => calculateDeliveryPricing(input), TypeError);
  }
});

test('rejects totals that exceed the safe integer range', () => {
  assert.throws(
    () => calculateDeliveryPricing({
      merchandiseSubtotalMinor: Number.MAX_SAFE_INTEGER,
      distanceMeters: MAX_DELIVERY_DISTANCE_METERS,
    }),
    TypeError,
  );
});
