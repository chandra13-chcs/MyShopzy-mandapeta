const DEFAULT_BPS = Object.freeze({
  restaurant: 1000,
  meat: 1000,
  bakery: 1000,
  fruits_vegetables: 500,
  local_store: 500,
});

const CATEGORY_CODE_BPS = Object.freeze({
  frozen_foods: 1000,
});

const COMMISSION_BASE = 'item_total_before_discount'; // Delivery fee and taxes are excluded.

function validateBps(value) {
  if (!Number.isSafeInteger(value) || value < 0 || value > 10000) {
    throw new RangeError('Commission basis points must be an integer from 0 to 10000.');
  }
  return value;
}

function resolveCommissionBps({
  categoryOverride,
  partnerOverride,
  categoryCode,
  partnerType,
}) {
  if (categoryOverride !== null && categoryOverride !== undefined) {
    return validateBps(categoryOverride);
  }
  if (partnerOverride !== null && partnerOverride !== undefined) {
    return validateBps(partnerOverride);
  }
  if (Object.hasOwn(CATEGORY_CODE_BPS, categoryCode)) {
    return CATEGORY_CODE_BPS[categoryCode];
  }
  if (!Object.hasOwn(DEFAULT_BPS, partnerType)) {
    throw new RangeError(`Unknown partner type: ${partnerType}`);
  }
  return DEFAULT_BPS[partnerType];
}

function toMinorUnits(value) {
  if (typeof value === 'bigint') {
    if (value < 0n) throw new RangeError('Minor-unit values cannot be negative.');
    return value;
  }
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value) || value < 0) {
      throw new RangeError('Minor-unit values must be non-negative safe integers.');
    }
    return BigInt(value);
  }
  if (typeof value === 'string' && /^\d+$/.test(value)) return BigInt(value);
  throw new TypeError('Minor-unit values must be integers.');
}

function computeCommissionMinor(lineTotalMinor, bps) {
  const total = toMinorUnits(lineTotalMinor);
  const rate = BigInt(validateBps(bps));
  return (total * rate + 5000n) / 10000n;
}

function sumDeliveredCommissionMinor(orders) {
  if (!Array.isArray(orders)) throw new TypeError('Orders must be an array.');
  return orders.reduce((sum, order) => {
    if (order.status !== 'delivered') return sum;
    return sum + toMinorUnits(order.commission_minor);
  }, 0n);
}

module.exports = {
  COMMISSION_BASE,
  CATEGORY_CODE_BPS,
  DEFAULT_BPS,
  computeCommissionMinor,
  resolveCommissionBps,
  sumDeliveredCommissionMinor,
};