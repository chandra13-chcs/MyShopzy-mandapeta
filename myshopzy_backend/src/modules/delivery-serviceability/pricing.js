const FREE_DELIVERY_THRESHOLD_MINOR = 49900;
const MAX_DELIVERY_DISTANCE_METERS = 18000;
const FLAT_DELIVERY_DISTANCE_METERS = 4000;
const FLAT_DELIVERY_FEE_MINOR = 3000;
const PER_KILOMETER_FEE_MINOR = 600;
const PLATFORM_FEE_MINOR = 1000;

function assertSafeNonNegativeInteger(value, label) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new TypeError(`${label} must be a non-negative safe integer.`);
  }
}

function calculateDeliveryPricing({
  merchandiseSubtotalMinor,
  distanceMeters,
}) {
  assertSafeNonNegativeInteger(
    merchandiseSubtotalMinor,
    'merchandiseSubtotalMinor',
  );
  assertSafeNonNegativeInteger(distanceMeters, 'distanceMeters');

  if (distanceMeters > MAX_DELIVERY_DISTANCE_METERS) {
    return Object.freeze({
      deliverable: false,
      reason: 'OUTSIDE_DELIVERY_RANGE',
      merchandiseSubtotalMinor,
      distanceMeters,
      deliveryFeeMinor: null,
      platformFeeMinor: null,
      totalMinor: null,
    });
  }

  let deliveryFeeMinor = 0;
  if (merchandiseSubtotalMinor < FREE_DELIVERY_THRESHOLD_MINOR) {
    if (distanceMeters <= FLAT_DELIVERY_DISTANCE_METERS) {
      deliveryFeeMinor = FLAT_DELIVERY_FEE_MINOR;
    } else {
      const feeNumerator = PER_KILOMETER_FEE_MINOR * distanceMeters;
      deliveryFeeMinor = Math.floor((feeNumerator + 500) / 1000);
    }
  }

  const totalMinor =
    merchandiseSubtotalMinor + deliveryFeeMinor + PLATFORM_FEE_MINOR;
  if (!Number.isSafeInteger(totalMinor)) {
    throw new TypeError('The calculated order total exceeds the safe integer range.');
  }

  return Object.freeze({
    deliverable: true,
    reason: null,
    merchandiseSubtotalMinor,
    distanceMeters,
    deliveryFeeMinor,
    platformFeeMinor: PLATFORM_FEE_MINOR,
    totalMinor,
  });
}

module.exports = {
  calculateDeliveryPricing,
  FREE_DELIVERY_THRESHOLD_MINOR,
  MAX_DELIVERY_DISTANCE_METERS,
  PLATFORM_FEE_MINOR,
};
