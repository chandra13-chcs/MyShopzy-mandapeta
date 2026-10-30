const express = require('express');
const { validateCoordinates } = require('../delivery-fee/distance');
const {
  CATEGORY_DELIVERY_LIMITS_METERS,
  MANDAPETA_BUS_STAND,
  assessCategoryServiceability,
} = require('./categories');

const PINCODE_PATTERN = /^\d{6}$/;
const ROUTE_CACHE_TTL_MS = 3 * 60 * 1000;
const MAX_ROUTE_CACHE_ENTRIES = 500;

function validateRequestBody(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return 'Request body must be a JSON object.';
  }
  const allowedKeys = new Set(['latitude', 'longitude', 'pincode']);
  if (Object.keys(body).some((key) => !allowedKeys.has(key))) {
    return 'Only latitude, longitude, and pincode are supported.';
  }
  if (
    typeof body.latitude !== 'number' ||
    !Number.isFinite(body.latitude) ||
    body.latitude < -90 ||
    body.latitude > 90
  ) {
    return 'latitude must be a finite number between -90 and 90.';
  }
  if (
    typeof body.longitude !== 'number' ||
    !Number.isFinite(body.longitude) ||
    body.longitude < -180 ||
    body.longitude > 180
  ) {
    return 'longitude must be a finite number between -180 and 180.';
  }
  if (typeof body.pincode !== 'string' || !PINCODE_PATTERN.test(body.pincode)) {
    return 'pincode must be a 6-digit string.';
  }
  return null;
}

function createDeliveryServiceabilityRouter({
  databasePool = null,
  deliveryDistanceClient = null,
  now = Date.now,
} = {}) {
  const router = express.Router();
  const routeCache = new Map();

  async function getRoadDistanceMeters(destination) {
    const cacheKey =
      `${destination.latitude.toFixed(6)},${destination.longitude.toFixed(6)}`;
    const cached = routeCache.get(cacheKey);
    if (cached && cached.expiresAt > now()) return cached.distanceMeters;
    if (cached) routeCache.delete(cacheKey);
    if (!deliveryDistanceClient) return null;

    const distanceMeters = await deliveryDistanceClient.getRoadDistanceMetres(
      MANDAPETA_BUS_STAND,
      destination,
    );
    if (!Number.isSafeInteger(distanceMeters) || distanceMeters < 0) {
      return null;
    }

    while (routeCache.size >= MAX_ROUTE_CACHE_ENTRIES) {
      routeCache.delete(routeCache.keys().next().value);
    }
    routeCache.set(cacheKey, {
      distanceMeters,
      expiresAt: now() + ROUTE_CACHE_TTL_MS,
    });
    return distanceMeters;
  }

  router.post('/delivery/category-serviceability', async (req, res) => {
    const body = req.body;
    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body) ||
      Object.keys(body).some(
        (key) => !['category', 'latitude', 'longitude'].includes(key),
      ) ||
      typeof body.category !== 'string' ||
      !Object.hasOwn(CATEGORY_DELIVERY_LIMITS_METERS, body.category)
    ) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'A supported category and valid destination are required.',
        },
      });
    }

    let destination;
    try {
      destination = validateCoordinates({
        latitude: body.latitude,
        longitude: body.longitude,
      });
    } catch {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'Enter valid destination coordinates within India.',
        },
      });
    }

    try {
      const distanceMeters = await getRoadDistanceMeters(destination);
      if (distanceMeters === null) {
        return res.status(503).json({
          error: {
            code: 'ROUTING_UNAVAILABLE',
            message: 'We could not verify the driving route. Please try again.',
          },
        });
      }
      return res.status(200).json({
        data: assessCategoryServiceability(body.category, distanceMeters),
      });
    } catch {
      return res.status(503).json({
        error: {
          code: 'ROUTING_UNAVAILABLE',
          message: 'We could not verify the driving route. Please try again.',
        },
      });
    }
  });

  router.post('/delivery/serviceability', async (req, res, next) => {
    const validationError = validateRequestBody(req.body);
    if (validationError) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: validationError },
      });
    }
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Delivery serviceability is temporarily unavailable.',
        },
      });
    }

    try {
      const result = await databasePool.query(
        `SELECT EXISTS (
           SELECT 1
           FROM app.serviceable_pincodes
           WHERE pincode = $1
             AND is_active = true
         ) AS is_deliverable`,
        [req.body.pincode],
      );
      const isDeliverable = result.rows[0].is_deliverable;
      return res.status(200).json({
        data: {
          isDeliverable,
          message: isDeliverable
            ? 'Delivery is available at this location.'
            : 'Sorry, we do not deliver to this location.',
        },
      });
    } catch (error) {
      return next(error);
    }
  });

  return router;
}

module.exports = { createDeliveryServiceabilityRouter };
