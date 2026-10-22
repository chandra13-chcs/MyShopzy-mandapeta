const assert = require('node:assert/strict');
const test = require('node:test');

const {
  COMMISSION_BASE,
  CATEGORY_CODE_BPS,
  DEFAULT_BPS,
  computeCommissionMinor,
  resolveCommissionBps,
  sumDeliveredCommissionMinor,
} = require('../../src/modules/commission/rules');

test('uses the configured default rate for every supported partner type', () => {
  assert.deepEqual(DEFAULT_BPS, {
    restaurant: 1000,
    meat: 1000,
    bakery: 1000,
    fruits_vegetables: 500,
    local_store: 500,
  });
  for (const [partnerType, expectedBps] of Object.entries(DEFAULT_BPS)) {
    assert.equal(resolveCommissionBps({ partnerType }), expectedBps);
  }
  assert.equal(COMMISSION_BASE, 'item_total_before_discount');
});

test('category override charges 10 percent for frozen foods and default 5 percent for staples', () => {
  const localStore = { partnerType: 'local_store', partnerOverride: null };
  const rates = [
    resolveCommissionBps({ ...localStore, categoryOverride: 1000 }),
    resolveCommissionBps({ ...localStore, categoryOverride: null }),
  ];

  assert.deepEqual(rates, [1000, 500]);
});

test('partner override takes precedence over the partner-type default', () => {
  assert.equal(
    resolveCommissionBps({ partnerType: 'restaurant', partnerOverride: 750 }),
    750,
  );
});

test('category override takes precedence over partner override', () => {
  assert.equal(
    resolveCommissionBps({
      categoryOverride: 1000,
      partnerOverride: 750,
      partnerType: 'local_store',
    }),
    1000,
  );
});

test('applies category-code rates after overrides and before partner-type defaults', () => {
  assert.deepEqual(CATEGORY_CODE_BPS, { frozen_foods: 1000 });
  assert.equal(resolveCommissionBps({
    categoryCode: 'frozen_foods',
    partnerType: 'local_store',
  }), 1000);
  assert.equal(resolveCommissionBps({
    categoryCode: 'frozen_foods',
    partnerType: 'fruits_vegetables',
  }), 1000);
  assert.equal(resolveCommissionBps({
    categoryCode: 'unknown_code',
    partnerType: 'local_store',
  }), 500);
  assert.equal(resolveCommissionBps({
    categoryCode: 'frozen_foods',
    partnerOverride: 750,
    partnerType: 'local_store',
  }), 750);
});

test('calculates 7500 paise commission for staples and frozen foods local-store lines', () => {
  const staplesCommission = computeCommissionMinor(
    50000,
    resolveCommissionBps({ categoryCode: 'staples', partnerType: 'local_store' }),
  );
  const frozenCommission = computeCommissionMinor(
    50000,
    resolveCommissionBps({ categoryCode: 'frozen_foods', partnerType: 'local_store' }),
  );
  assert.equal(staplesCommission, 2500n);
  assert.equal(frozenCommission, 5000n);
  assert.equal(staplesCommission + frozenCommission, 7500n);
});

test('computes commissions with integer half-up rounding', () => {
  assert.equal(computeCommissionMinor('1', 5000), 1n);
  assert.equal(computeCommissionMinor('1', 4999), 0n);
  assert.equal(computeCommissionMinor('3', 5000), 2n);
  assert.equal(computeCommissionMinor('100', 125), 1n);
});

test('throws for unknown partner types instead of silently assigning zero', () => {
  assert.throws(
    () => resolveCommissionBps({ partnerType: 'unlisted_type' }),
    /Unknown partner type/,
  );
});

test('sums commission only for delivered orders', () => {
  assert.equal(sumDeliveredCommissionMinor([
    { status: 'delivered', commission_minor: '125' },
    { status: 'cancelled', commission_minor: '500' },
    { status: 'rejected', commission_minor: '250' },
    { status: 'placed', commission_minor: '75' },
  ]), 125n);
});