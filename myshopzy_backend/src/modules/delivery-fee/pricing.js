'use strict';

const FEE_RULES = Object.freeze({
  standard: Object.freeze({
    baseDistanceM: 4000,
    baseFeeMinor: 4000,
    perMetreMinor: 1,
  }),
  parcel: Object.freeze({
    baseDistanceM: 2000,
    baseFeeMinor: 2500,
    perMetreMinor: 1,
  }),
});

const RIDER_FEE_SHARE_BPS = 10000;

function computeDeliveryFeeMinor(kind, distanceM) {
  const rule = FEE_RULES[kind];
  if (!rule) throw new TypeError('kind must be standard or parcel.');
  if (!Number.isSafeInteger(distanceM) || distanceM < 0) {
    throw new TypeError('distanceM must be a non-negative integer.');
  }

  // 1 paisa per metre equals Rs 10 per km, pro-rata, with no full-km rounding.
  const feeMinor =
    rule.baseFeeMinor +
    Math.max(0, distanceM - rule.baseDistanceM) * rule.perMetreMinor;
  if (!Number.isSafeInteger(feeMinor)) {
    throw new TypeError('The computed delivery fee exceeds the safe integer range.');
  }
  return feeMinor;
}

module.exports = { FEE_RULES, RIDER_FEE_SHARE_BPS, computeDeliveryFeeMinor };
