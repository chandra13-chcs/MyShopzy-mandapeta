const express = require('express');

const PINCODE_PATTERN = /^\d{6}$/;

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

function createDeliveryServiceabilityRouter({ databasePool = null } = {}) {
  const router = express.Router();

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
