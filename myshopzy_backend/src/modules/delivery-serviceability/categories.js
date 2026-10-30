'use strict';

const CATEGORY_DELIVERY_LIMITS_METERS = Object.freeze({
  grocery: 10000,
  meat: 10000,
  vegetables_fruits: 10000,
  bakery: 10000,
  restaurant: 18000,
  parcel: 35000,
});

const PARTNER_TYPE_DELIVERY_CATEGORY = Object.freeze({
  grocery: 'grocery',
  local_store: 'grocery',
  meat: 'meat',
  meat_shop: 'meat',
  vegetables_fruits: 'vegetables_fruits',
  fruits_vegetables: 'vegetables_fruits',
  bakery: 'bakery',
  sweet_shop: 'bakery',
  restaurant: 'restaurant',
});

const MANDAPETA_BUS_STAND = Object.freeze({
  latitude: 16.8675417,
  longitude: 81.9272951,
  name: 'Mandapeta Bus Stand',
});

function deliveryCategoryForPartnerType(partnerType) {
  return Object.hasOwn(PARTNER_TYPE_DELIVERY_CATEGORY, partnerType)
    ? PARTNER_TYPE_DELIVERY_CATEGORY[partnerType]
    : null;
}

function assessCategoryServiceability(category, distanceMeters) {
  const maximumDistanceMeters = CATEGORY_DELIVERY_LIMITS_METERS[category];
  if (maximumDistanceMeters === undefined) {
    throw new TypeError('category must be a supported delivery category.');
  }
  if (!Number.isSafeInteger(distanceMeters) || distanceMeters < 0) {
    throw new TypeError('distanceMeters must be a non-negative integer.');
  }

  const isDeliverable = distanceMeters <= maximumDistanceMeters;
  const maximumDistanceKm = maximumDistanceMeters / 1000;
  return Object.freeze({
    category,
    isDeliverable,
    distanceMeters,
    maximumDistanceMeters,
    message: isDeliverable
      ? `Delivery is available within ${maximumDistanceKm} km of Mandapeta Bus Stand.`
      : `Sorry, this service is available only within ${maximumDistanceKm} km of Mandapeta Bus Stand.`,
  });
}

module.exports = {
  CATEGORY_DELIVERY_LIMITS_METERS,
  MANDAPETA_BUS_STAND,
  deliveryCategoryForPartnerType,
  assessCategoryServiceability,
};
