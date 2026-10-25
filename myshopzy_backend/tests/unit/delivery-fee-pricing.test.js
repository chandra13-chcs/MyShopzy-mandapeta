const assert = require('node:assert/strict');
const test = require('node:test');

const {
  FEE_RULES,
  RIDER_FEE_SHARE_BPS,
  computeDeliveryFeeMinor,
} = require('../../src/modules/delivery-fee/pricing');

test('computes the standard delivery fee at and above its base distance', () => {
  assert.equal(computeDeliveryFeeMinor('standard', 2500), 4000);
  assert.equal(computeDeliveryFeeMinor('standard', 4000), 4000);
  assert.equal(computeDeliveryFeeMinor('standard', 5700), 5700);
  assert.equal(computeDeliveryFeeMinor('standard', 10000), 10000);
});

test('computes the parcel fee at and above its base distance', () => {
  assert.equal(computeDeliveryFeeMinor('parcel', 1500), 2500);
  assert.equal(computeDeliveryFeeMinor('parcel', 2000), 2500);
  assert.equal(computeDeliveryFeeMinor('parcel', 2500), 3000);
  assert.equal(computeDeliveryFeeMinor('parcel', 4000), 4500);
  assert.equal(computeDeliveryFeeMinor('parcel', 5700), 6200);
});

test('rejects invalid distance values and fee kinds', () => {
  for (const distanceM of [-1, 1.5, Number.MAX_SAFE_INTEGER + 1]) {
    assert.throws(() => computeDeliveryFeeMinor('standard', distanceM), TypeError);
  }
  assert.throws(() => computeDeliveryFeeMinor('unknown', 1000), TypeError);
});

test('uses full rider fee share', () => {
  assert.equal(RIDER_FEE_SHARE_BPS, 10000);
  assert.deepEqual(FEE_RULES.standard, {
    baseDistanceM: 4000,
    baseFeeMinor: 4000,
    perMetreMinor: 1,
  });
});
