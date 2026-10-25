const express = require('express');
const { RIDER_FEE_SHARE_BPS } = require('../delivery-fee/pricing');
const { createPendingDue } = require('../dues/ledger');
const { DUE_POLICY } = require('../dues/policy');

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const RIDER_STATUSES = new Set(['picked_up', 'out_for_delivery', 'delivered']);
const RIDER_HOURS = Object.freeze({ open: '07:00', close: '22:00' });
const RIDER_LOCATION_MAX_AGE_MS = 60_000;
const RIDER_LOCATION_STALE_MS = 120_000;
const RIDER_OFFER_RADIUS_M = parsePositiveIntegerEnv(
  'RIDER_OFFER_RADIUS_M',
  5000,
);
const RIDER_MAX_ACTIVE_ORDERS = parsePositiveIntegerEnv(
  'RIDER_MAX_ACTIVE_ORDERS',
  2,
);
const DELIVERY_FAILURE_REASONS = new Set([
  'customer_refused',
  'customer_unreachable',
  'wrong_address_by_customer',
]);

class ApiError extends Error {
  constructor(status, code, message, details = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function sendApiError(res, error) {
  return res.status(error.status).json({
    error: { code: error.code, message: error.message, ...error.details },
  });
}

function parsePositiveIntegerEnv(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`${name} must be a positive integer.`);
  }
  return value;
}

function getRiderDutyStatus(now) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Kolkata',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const localTime = parts
    .filter((part) => part.type === 'hour' || part.type === 'minute')
    .map((part) => part.value)
    .join(':');
  const currentMinutes =
    Number(localTime.slice(0, 2)) * 60 + Number(localTime.slice(3));
  const toMinutes = (time) =>
    Number(time.slice(0, 2)) * 60 + Number(time.slice(3));
  const openingMinutes = toMinutes(RIDER_HOURS.open);
  const closingMinutes = toMinutes(RIDER_HOURS.close);
  return {
    open: currentMinutes >= openingMinutes && currentMinutes < closingMinutes,
    opensAt: RIDER_HOURS.open,
    closesAt: RIDER_HOURS.close,
  };
}

function validateLocationFix(body, now) {
  const requiredFields = [
    'latitude',
    'longitude',
    'accuracy',
    'capturedAt',
  ];
  if (
    requiredFields.some((field) => body[field] === undefined) ||
    typeof body.latitude !== 'number' ||
    !Number.isFinite(body.latitude) ||
    body.latitude < -90 ||
    body.latitude > 90 ||
    typeof body.longitude !== 'number' ||
    !Number.isFinite(body.longitude) ||
    body.longitude < -180 ||
    body.longitude > 180 ||
    typeof body.accuracy !== 'number' ||
    !Number.isFinite(body.accuracy) ||
    body.accuracy < 0 ||
    typeof body.capturedAt !== 'string' ||
    !Number.isFinite(Date.parse(body.capturedAt))
  ) {
    throw new ApiError(
      422,
      'LOCATION_REQUIRED',
      'A valid latitude, longitude, accuracy, and capturedAt are required.',
    );
  }
  const capturedAtMs = Date.parse(body.capturedAt);
  const ageMs = now.getTime() - capturedAtMs;
  if (ageMs > RIDER_LOCATION_MAX_AGE_MS || ageMs < -5000) {
    throw new ApiError(
      422,
      'LOCATION_STALE',
      'The location fix must be no older than 60 seconds.',
    );
  }
  return {
    latitude: body.latitude,
    longitude: body.longitude,
    accuracy: body.accuracy,
    capturedAt: new Date(capturedAtMs).toISOString(),
  };
}

function isLocationStale(rider, now) {
  const updatedAt = new Date(rider.current_location_updated_at).getTime();
  return (
    !Number.isFinite(updatedAt) ||
    now.getTime() - updatedAt > RIDER_LOCATION_STALE_MS
  );
}

function haversineDistanceMetres(first, second) {
  const radians = (degrees) => (degrees * Math.PI) / 180;
  const latitudeDelta = radians(second.latitude - first.latitude);
  const longitudeDelta = radians(second.longitude - first.longitude);
  const rawA =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(radians(first.latitude)) *
      Math.cos(radians(second.latitude)) *
      Math.sin(longitudeDelta / 2) ** 2;
  const a = Math.min(1, Math.max(0, rawA));
  return Math.round(6_371_000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

function getOfferBounds(coordinates, radiusM) {
  const latitudeDelta = radiusM / 111_320;
  const longitudeScale = Math.max(
    Math.cos((coordinates.latitude * Math.PI) / 180),
    0.01,
  );
  const longitudeDelta = radiusM / (111_320 * longitudeScale);
  return {
    minLatitude: coordinates.latitude - latitudeDelta,
    maxLatitude: coordinates.latitude + latitudeDelta,
    minLongitude: coordinates.longitude - longitudeDelta,
    maxLongitude: coordinates.longitude + longitudeDelta,
  };
}

function requireRiderAuthentication(authenticateRider) {
  return (req, res, next) => {
    if (typeof authenticateRider !== 'function') {
      return res.status(401).json({
        error: {
          code: 'AUTHENTICATION_REQUIRED',
          message: 'Rider authentication is required.',
        },
      });
    }
    try {
      const result = authenticateRider(req, res, next);
      if (result && typeof result.catch === 'function') result.catch(next);
      return result;
    } catch (error) {
      return next(error);
    }
  };
}

function getRiderUserId(req) {
  const riderUserId = req.auth?.riderUserId;
  if (typeof riderUserId !== 'string' || !UUID_PATTERN.test(riderUserId)) {
    throw new ApiError(
      401,
      'AUTHENTICATION_REQUIRED',
      'Rider authentication is required.',
    );
  }
  return riderUserId;
}

function validateObjectBody(body, allowedFields) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return 'Request body must be a JSON object.';
  }
  const unsupportedField = Object.keys(body).find(
    (field) => !allowedFields.has(field),
  );
  if (unsupportedField) return `Unsupported request field: ${unsupportedField}.`;
  return null;
}

function validateOrderId(orderId) {
  if (!UUID_PATTERN.test(orderId)) {
    return new ApiError(400, 'INVALID_REQUEST', 'orderId must be a valid UUID.');
  }
  return null;
}

async function withTransaction(databasePool, callback) {
  const client = await databasePool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackError) {
      throw new AggregateError(
        [error, rollbackError],
        'The rider transaction failed and could not be rolled back.',
      );
    }
    throw error;
  } finally {
    client.release();
  }
}

async function requireActiveRider(
  queryable,
  riderUserId,
  { lock = false, forUpdate = false } = {},
) {
  const result = await queryable.query(
    `SELECT r.user_id, r.is_online, r.current_latitude,
            r.current_longitude, r.current_location_accuracy,
            r.current_location_updated_at,
            (SELECT COUNT(*)::int
             FROM app.orders AS active_order
             WHERE active_order.rider_id = r.user_id
               AND active_order.status IN ('out_for_delivery', 'picked_up')
            ) AS active_order_count
     FROM app.riders AS r
     JOIN app.users AS u ON u.id = r.user_id
     WHERE r.user_id = $1
       AND r.status = 'active'
       AND u.system_role = 'rider'
       AND u.status = 'active'
     ${forUpdate ? 'FOR UPDATE OF r, u' : lock ? 'FOR SHARE OF r, u' : ''}`,
    [riderUserId],
  );
  if (result.rows.length === 0) {
    throw new ApiError(403, 'RIDER_NOT_ALLOWED', 'The rider account is not active.');
  }
  return result.rows[0];
}

function createRiderRouter({
  databasePool = null,
  authenticateRider = null,
  now = () => new Date(),
  canAcceptOrders = () => true,
  applyRiderCancelPenalty = async () => {},
  offerRadiusM = RIDER_OFFER_RADIUS_M,
  maxActiveOrders = RIDER_MAX_ACTIVE_ORDERS,
  supportPhone = '+91 88972 67490',
  supportEscalationMinutes = 10,
} = {}) {
  const router = express.Router();
  router.use('/rider', requireRiderAuthentication(authenticateRider));

  router.patch('/rider/orders/:orderId/arrived', async (req, res, next) => {
    const invalidOrderId = validateOrderId(req.params.orderId);
    if (invalidOrderId) return sendApiError(res, invalidOrderId);
    const bodyError =
      req.body === undefined ? null : validateObjectBody(req.body, new Set());
    if (bodyError) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: bodyError },
      });
    }
    let riderUserId;
    try {
      riderUserId = getRiderUserId(req);
    } catch (error) {
      return sendApiError(res, error);
    }
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Rider orders are temporarily unavailable.',
        },
      });
    }

    try {
      const order = await withTransaction(databasePool, async (client) => {
        await requireActiveRider(client, riderUserId, { lock: true });
        const current = await client.query(
          `SELECT id, rider_id, status, rider_stage
           FROM app.orders
           WHERE id = $1
           FOR UPDATE`,
          [req.params.orderId],
        );
        if (
          current.rows.length === 0 ||
          current.rows[0].rider_id !== riderUserId
        ) {
          throw new ApiError(
            404,
            'ORDER_NOT_ASSIGNED',
            'The order is not assigned to this rider.',
          );
        }
        if (
          current.rows[0].status !== 'out_for_delivery' ||
          current.rows[0].rider_stage !== 'out_for_delivery'
        ) {
          throw new ApiError(
            409,
            'ORDER_NOT_IN_DELIVERY',
            'Only orders in the out-for-delivery stage can be marked as arrived.',
          );
        }
        const updated = await client.query(
          `UPDATE app.orders
           SET rider_arrived_at = COALESCE(rider_arrived_at, now()),
               updated_at = CASE
                 WHEN rider_arrived_at IS NULL THEN now()
                 ELSE updated_at
               END
           WHERE id = $1 AND rider_id = $2
             AND status = 'out_for_delivery'
             AND rider_stage = 'out_for_delivery'
           RETURNING rider_arrived_at`,
          [req.params.orderId, riderUserId],
        );
        if (updated.rows.length !== 1) {
          throw new ApiError(
            409,
            'ORDER_NOT_IN_DELIVERY',
            'Only orders in the out-for-delivery stage can be marked as arrived.',
          );
        }
        const riderArrivedAt = updated.rows[0].rider_arrived_at;
        const supportAvailableAt = new Date(
          new Date(riderArrivedAt).getTime() +
            supportEscalationMinutes * 60_000,
        ).toISOString();
        return {
          orderId: req.params.orderId,
          rider_arrived_at: riderArrivedAt,
          supportAvailableAt,
          supportPhone,
        };
      });
      return res.status(200).json({ data: { order } });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.get('/rider/orders/available', async (req, res, next) => {
    let riderUserId;
    try {
      riderUserId = getRiderUserId(req);
    } catch (error) {
      return sendApiError(res, error);
    }
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Rider orders are temporarily unavailable.',
        },
      });
    }

    try {
      const rider = await requireActiveRider(databasePool, riderUserId);
      if (!rider.is_online) {
        return res.status(403).json({
          error: { code: 'RIDER_OFFLINE', message: 'Rider is offline.' },
        });
      }
      const serverNow = now();
      if (!getRiderDutyStatus(serverNow).open) {
        return res.status(200).json({ data: { orders: [] } });
      }
      if (isLocationStale(rider, serverNow)) {
        return res.status(200).json({ data: { orders: [] } });
      }
      if (rider.active_order_count >= maxActiveOrders) {
        return res.status(200).json({ data: { orders: [] } });
      }
      if (!(await canAcceptOrders(rider))) {
        return res.status(200).json({ data: { orders: [] } });
      }
      const riderCoordinates = {
        latitude: Number(rider.current_latitude),
        longitude: Number(rider.current_longitude),
      };
      if (
        !Number.isFinite(riderCoordinates.latitude) ||
        !Number.isFinite(riderCoordinates.longitude)
      ) {
        return res.status(200).json({ data: { orders: [] } });
      }
      const bounds = getOfferBounds(riderCoordinates, offerRadiusM);
      const result = await databasePool.query(
        `SELECT
           o.id AS "orderId",
           COALESCE(
             s.address->>'area',
             s.address->>'locality',
             s.address->>'city',
             ''
           ) AS "pickupArea",
           o.delivery_distance_m AS "distanceMeters",
           o.delivery_fee_minor::text AS "deliveryFeeMinor",
           o.payment_method AS "paymentMethod",
           CASE WHEN o.payment_method = 'cod'
             THEN o.total_minor::text END AS "codAmountMinor",
           s.latitude::double precision AS "pickupLatitude",
           s.longitude::double precision AS "pickupLongitude"
         FROM app.orders AS o
         JOIN app.shops AS s
           ON s.id = o.shop_id AND s.partner_id = o.partner_id
         WHERE o.status = 'packed'
           AND o.rider_id IS NULL
           AND s.latitude BETWEEN $1 AND $2
           AND s.longitude BETWEEN $3 AND $4
         ORDER BY o.placed_at ASC, o.id ASC`,
        [
          bounds.minLatitude,
          bounds.maxLatitude,
          bounds.minLongitude,
          bounds.maxLongitude,
        ],
      );
      const orders = result.rows
        .filter((order) => {
          if (
            !Number.isSafeInteger(order.distanceMeters) ||
            order.distanceMeters < 0 ||
            !Number.isFinite(Number(order.pickupLatitude)) ||
            !Number.isFinite(Number(order.pickupLongitude))
          ) {
            return false;
          }
          const pickupDistanceM = haversineDistanceMetres(
            riderCoordinates,
            {
              latitude: Number(order.pickupLatitude),
              longitude: Number(order.pickupLongitude),
            },
          );
          return pickupDistanceM <= offerRadiusM;
        })
        .map(({ pickupLatitude, pickupLongitude, ...order }) => order);
      return res.status(200).json({ data: { orders } });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.post('/rider/orders/:orderId/accept', async (req, res, next) => {
    const invalidOrderId = validateOrderId(req.params.orderId);
    if (invalidOrderId) return sendApiError(res, invalidOrderId);
    let riderUserId;
    try {
      riderUserId = getRiderUserId(req);
    } catch (error) {
      return sendApiError(res, error);
    }
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Rider orders are temporarily unavailable.',
        },
      });
    }

    try {
      const order = await withTransaction(databasePool, async (client) => {
        const rider = await requireActiveRider(client, riderUserId, {
          forUpdate: true,
        });
        if (!rider.is_online) {
          throw new ApiError(403, 'RIDER_OFFLINE', 'Rider is offline');
        }
        const serverNow = now();
        const duty = getRiderDutyStatus(serverNow);
        if (!duty.open) {
          throw new ApiError(
            403,
            'RIDER_OUTSIDE_HOURS',
            'Riders may accept new orders only between 7:00 AM and 10:00 PM.',
            { opensAt: duty.opensAt },
          );
        }
        if (isLocationStale(rider, serverNow)) {
          throw new ApiError(
            403,
            'RIDER_LOCATION_STALE',
            'Share a fresh location before accepting orders.',
          );
        }
        if (!(await canAcceptOrders(rider))) {
          throw new ApiError(
            403,
            'RIDER_CANNOT_ACCEPT_ORDERS',
            'This rider cannot accept new orders.',
          );
        }
        const activeOrders = await client.query(
          `SELECT COUNT(*)::int AS count
           FROM app.orders
           WHERE rider_id = $1
             AND status IN ('out_for_delivery', 'picked_up')`,
          [riderUserId],
        );
        if (activeOrders.rows[0].count >= maxActiveOrders) {
          throw new ApiError(
            409,
            'RIDER_ACTIVE_ORDER_LIMIT',
            'The rider already has the maximum number of active orders.',
          );
        }

        const accepted = await client.query(
          `UPDATE app.orders
           SET rider_id = $2,
               status = 'out_for_delivery',
               rider_stage = 'accepted',
               updated_at = now()
           WHERE id = $1
             AND status = 'packed'
             AND rider_id IS NULL
           RETURNING id AS "orderId", status, rider_id AS "riderId",
                     updated_at AS "updatedAt"`,
          [req.params.orderId, riderUserId],
        );
        if (accepted.rows.length === 0) {
          throw new ApiError(
            409,
            'ORDER_TAKEN',
            'This order has already been accepted.',
          );
        }
        const details = await client.query(
          `SELECT
             o.id AS "orderId",
             o.status,
             s.name AS store,
             s.address AS pickup,
             o.delivery_address_snapshot AS drop,
             cu.display_name AS "customerName",
             cu.phone AS "customerPhone",
             p.contact_phone AS "storePhone",
             (o.delivery_fee_minor::numeric / 100)::numeric(12, 2) AS payout,
             CASE WHEN s.address->>'latitude' ~ '^-?[0-9]+([.][0-9]+)?$'
               THEN (s.address->>'latitude')::numeric END AS "pickupLatitude",
             CASE WHEN s.address->>'longitude' ~ '^-?[0-9]+([.][0-9]+)?$'
               THEN (s.address->>'longitude')::numeric END AS "pickupLongitude",
             CASE WHEN o.delivery_address_snapshot->>'latitude' ~ '^-?[0-9]+([.][0-9]+)?$'
               THEN (o.delivery_address_snapshot->>'latitude')::numeric END AS "dropLatitude",
             CASE WHEN o.delivery_address_snapshot->>'longitude' ~ '^-?[0-9]+([.][0-9]+)?$'
               THEN (o.delivery_address_snapshot->>'longitude')::numeric END AS "dropLongitude"
           FROM app.orders AS o
           JOIN app.shops AS s
             ON s.id = o.shop_id AND s.partner_id = o.partner_id
           JOIN app.partners AS p ON p.id = s.partner_id
           JOIN app.users AS cu ON cu.id = o.customer_user_id
           WHERE o.id = $1 AND o.rider_id = $2`,
          [req.params.orderId, riderUserId],
        );
        return { ...accepted.rows[0], ...details.rows[0] };
      });
      return res.status(200).json({ data: { order } });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.patch('/rider/orders/:orderId/cancel', async (req, res, next) => {
    const invalidOrderId = validateOrderId(req.params.orderId);
    if (invalidOrderId) return sendApiError(res, invalidOrderId);
    const bodyError = validateObjectBody(req.body, new Set(['reason']));
    const reason = req.body?.reason;
    if (
      bodyError ||
      typeof reason !== 'string' ||
      reason.trim().length === 0 ||
      reason.trim().length > 300
    ) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: bodyError ?? 'reason must be a non-empty string of at most 300 characters.',
        },
      });
    }
    let riderUserId;
    try {
      riderUserId = getRiderUserId(req);
    } catch (error) {
      return sendApiError(res, error);
    }
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Rider orders are temporarily unavailable.',
        },
      });
    }

    try {
      const order = await withTransaction(databasePool, async (client) => {
        await requireActiveRider(client, riderUserId, { forUpdate: true });
        const result = await client.query(
          `UPDATE app.orders
           SET rider_id = NULL,
               status = 'packed',
               rider_stage = 'accepted',
               cancellation_reason = $3,
               updated_at = now()
           WHERE id = $1
             AND rider_id = $2
             AND status = 'out_for_delivery'
             AND rider_stage = 'accepted'
           RETURNING id AS "orderId", status, rider_id AS "riderId",
                     cancellation_reason AS "cancellationReason",
                     updated_at AS "updatedAt"`,
          [req.params.orderId, riderUserId, reason.trim()],
        );
        if (result.rows.length === 0) {
          throw new ApiError(
            404,
            'ORDER_NOT_ASSIGNED',
            'The order is not assigned to this rider or has already been picked up.',
          );
        }
        await applyRiderCancelPenalty(
          client,
          riderUserId,
          req.params.orderId,
        );
        return result.rows[0];
      });
      return res.status(200).json({ data: { order } });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.patch('/rider/orders/:orderId/status', async (req, res, next) => {
    const invalidOrderId = validateOrderId(req.params.orderId);
    if (invalidOrderId) return sendApiError(res, invalidOrderId);
    const bodyError = validateObjectBody(req.body, new Set(['status']));
    if (bodyError) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: bodyError },
      });
    }
    if (typeof req.body.status !== 'string' || !RIDER_STATUSES.has(req.body.status)) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'status must be picked_up, out_for_delivery, or delivered.',
        },
      });
    }
    let riderUserId;
    try {
      riderUserId = getRiderUserId(req);
    } catch (error) {
      return sendApiError(res, error);
    }
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Rider orders are temporarily unavailable.',
        },
      });
    }

    try {
      const order = await withTransaction(databasePool, async (client) => {
        await requireActiveRider(client, riderUserId, { lock: true });
        const expectedStage = {
          picked_up: 'accepted',
          out_for_delivery: 'picked_up',
          delivered: 'out_for_delivery',
        }[req.body.status];
        const result = await client.query(
          `UPDATE app.orders
           SET status = $3,
               rider_stage = $3,
               updated_at = now()
           WHERE id = $1
             AND rider_id = $2
             AND status IN ('picked_up', 'out_for_delivery')
             AND rider_stage IN ($3, $4)
           RETURNING id AS "orderId", status, rider_id AS "riderId",
                     updated_at AS "updatedAt",
                     delivery_fee_minor::text AS "deliveryFeeMinor",
                     currency`,
          [req.params.orderId, riderUserId, req.body.status, expectedStage],
        );
        if (result.rows.length === 0) {
          throw new ApiError(
            404,
            'ORDER_NOT_ASSIGNED',
            'The order is not assigned to this rider or cannot be updated.',
          );
        }
        if (req.body.status === 'delivered') {
          const payoutMinor = (
            (BigInt(result.rows[0].deliveryFeeMinor) *
              BigInt(RIDER_FEE_SHARE_BPS)) /
            10000n
          ).toString();
          await client.query(
            `INSERT INTO app.rider_delivery_earnings
               (order_id, rider_id, payout_minor, currency)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (order_id) DO NOTHING`,
            [
              result.rows[0].orderId,
              riderUserId,
              payoutMinor,
              result.rows[0].currency,
            ],
          );
          result.rows[0].payoutMinor = payoutMinor;
          delete result.rows[0].deliveryFeeMinor;
        }
        return result.rows[0];
      });
      return res.status(200).json({ data: { order } });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.patch('/rider/orders/:orderId/delivery-failed', async (req, res, next) => {
    const invalidOrderId = validateOrderId(req.params.orderId);
    if (invalidOrderId) return sendApiError(res, invalidOrderId);
    const bodyError = validateObjectBody(
      req.body,
      new Set(['reason', 'note', 'attempts']),
    );
    if (bodyError) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: bodyError },
      });
    }
    const { reason, note, attempts } = req.body;
    if (!DELIVERY_FAILURE_REASONS.has(reason)) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'reason must be customer_refused, customer_unreachable, or wrong_address_by_customer.',
        },
      });
    }
    if (
      (note !== undefined &&
        (typeof note !== 'string' || note.length > 300)) ||
      !Number.isInteger(attempts) ||
      attempts < 0 ||
      attempts > 10
    ) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'note must be at most 300 characters and attempts must be an integer between 0 and 10.',
        },
      });
    }

    let riderUserId;
    try {
      riderUserId = getRiderUserId(req);
    } catch (error) {
      return sendApiError(res, error);
    }
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Rider orders are temporarily unavailable.',
        },
      });
    }

    try {
      const order = await withTransaction(databasePool, async (client) => {
        await requireActiveRider(client, riderUserId, { lock: true });
        const current = await client.query(
          `SELECT o.id, o.customer_user_id, o.rider_id, o.status, o.rider_stage,
                  o.rider_arrived_at,
                  o.payment_method, o.total_minor::text AS total_minor,
                  o.currency, r.current_latitude, r.current_longitude
           FROM app.orders AS o
           LEFT JOIN app.riders AS r ON r.user_id = o.rider_id
           WHERE o.id = $1
           FOR UPDATE OF o`,
          [req.params.orderId],
        );
        if (current.rows.length === 0 || current.rows[0].rider_id !== riderUserId) {
          throw new ApiError(
            404,
            'ORDER_NOT_ASSIGNED',
            'The order is not assigned to this rider.',
          );
        }
        const existing = current.rows[0];
        if (
          existing.status !== 'out_for_delivery' ||
          existing.rider_stage !== 'out_for_delivery'
        ) {
          throw new ApiError(
            409,
            'ORDER_NOT_IN_DELIVERY',
            'Only orders in the out-for-delivery stage can be marked as failed.',
          );
        }
        const serverNow = now();
        const arrivedAt = existing.rider_arrived_at
          ? new Date(existing.rider_arrived_at)
          : null;
        const supportAvailableAt = arrivedAt
          ? new Date(
              arrivedAt.getTime() + supportEscalationMinutes * 60_000,
            )
          : null;
        if (!supportAvailableAt || serverNow < supportAvailableAt) {
          const remainingSeconds = supportAvailableAt
            ? Math.max(
                0,
                Math.ceil((supportAvailableAt.getTime() - serverNow.getTime()) / 1000),
              )
            : supportEscalationMinutes * 60;
          throw new ApiError(
            409,
            'SUPPORT_WAIT_NOT_ELAPSED',
            'The support waiting period has not elapsed.',
            {
              remainingSeconds,
              ...(supportAvailableAt
                ? { supportAvailableAt: supportAvailableAt.toISOString() }
                : {}),
            },
          );
        }
        const updated = await client.query(
          `UPDATE app.orders
           SET status = 'delivery_failed',
               delivery_failure_reason = $2,
               delivery_failed_at = now(),
               delivery_failure_note = $3,
               delivery_failure_attempts = $4,
               delivery_failure_latitude = $5,
               delivery_failure_longitude = $6,
               updated_at = now()
           WHERE id = $1 AND rider_id = $7
             AND status = 'out_for_delivery'
             AND rider_stage = 'out_for_delivery'
           RETURNING id AS "orderId", status, rider_id AS "riderId",
                     delivery_failure_reason AS reason,
                     delivery_failed_at AS "deliveryFailedAt"`,
          [
            existing.id,
            reason,
            note ?? null,
            attempts,
            existing.current_latitude,
            existing.current_longitude,
            riderUserId,
          ],
        );
        if (updated.rows.length !== 1) {
          throw new ApiError(
            409,
            'ORDER_NOT_IN_DELIVERY',
            'Only orders in the out-for-delivery stage can be marked as failed.',
          );
        }
        if (existing.payment_method === 'cod') {
          const amountMinor = DUE_POLICY.amountMinor(existing);
          if (BigInt(amountMinor) > 0n) {
            await createPendingDue(client, {
              customerUserId: existing.customer_user_id,
              orderId: existing.id,
              amountMinor,
              currency: existing.currency,
              reason,
              note: note ?? null,
              evidence: {
                attempts,
                latitude: existing.current_latitude,
                longitude: existing.current_longitude,
              },
              createdByActor: `rider:${riderUserId}`,
            });
          }
        }
        return updated.rows[0];
      });
      return res.status(200).json({ data: { order } });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.patch('/rider/availability', async (req, res, next) => {
    const bodyError = validateObjectBody(
      req.body,
      new Set([
        'isOnline',
        'latitude',
        'longitude',
        'accuracy',
        'capturedAt',
      ]),
    );
    if (bodyError || typeof req.body.isOnline !== 'boolean') {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: bodyError ?? 'isOnline must be a boolean.',
        },
      });
    }
    let locationFix = null;
    if (req.body.isOnline) {
      try {
        locationFix = validateLocationFix(req.body, now());
      } catch (error) {
        if (error instanceof ApiError) return sendApiError(res, error);
        throw error;
      }
    }
    let riderUserId;
    try {
      riderUserId = getRiderUserId(req);
    } catch (error) {
      return sendApiError(res, error);
    }
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Rider availability is temporarily unavailable.',
        },
      });
    }

    try {
      const serverNow = now();
      if (req.body.isOnline) {
        const current = await requireActiveRider(databasePool, riderUserId);
        if (
          !current.is_online &&
          !getRiderDutyStatus(serverNow).open
        ) {
          return sendApiError(
            res,
            new ApiError(
              403,
              'RIDER_OUTSIDE_HOURS',
              'Riders may go online only between 7:00 AM and 10:00 PM.',
              { opensAt: RIDER_HOURS.open },
            ),
          );
        }
      }
      const result = await databasePool.query(
        `UPDATE app.riders AS r
         SET is_online = CASE
               WHEN EXISTS (
                 SELECT 1 FROM app.orders AS active_order
                 WHERE active_order.rider_id = r.user_id
                   AND active_order.status IN ('out_for_delivery', 'picked_up')
               ) THEN true
               ELSE $2
             END,
             current_latitude = CASE WHEN $2 THEN $3 ELSE r.current_latitude END,
             current_longitude = CASE WHEN $2 THEN $4 ELSE r.current_longitude END,
             current_location_accuracy = CASE
               WHEN $2 THEN $5 ELSE r.current_location_accuracy END,
             current_location_updated_at = CASE
               WHEN $2 THEN $6::timestamptz
               ELSE r.current_location_updated_at END,
             updated_at = now()
         FROM app.users AS u
         WHERE r.user_id = $1
           AND u.id = r.user_id
           AND r.status = 'active'
           AND u.system_role = 'rider'
           AND u.status = 'active'
         RETURNING r.is_online AS "isOnline",
                   r.current_latitude AS latitude,
                   r.current_longitude AS longitude,
                   r.current_location_accuracy AS accuracy,
                   r.current_location_updated_at AS "locationUpdatedAt"`,
        [
          riderUserId,
          req.body.isOnline,
          locationFix?.latitude ?? null,
          locationFix?.longitude ?? null,
          locationFix?.accuracy ?? null,
          locationFix?.capturedAt ?? null,
        ],
      );
      if (result.rows.length === 0) {
        throw new ApiError(
          403,
          'RIDER_NOT_ALLOWED',
          'The rider account is not active.',
        );
      }
      return res.status(200).json({ data: { availability: result.rows[0] } });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.get('/rider/earnings/summary', async (req, res, next) => {
    let riderUserId;
    try {
      riderUserId = getRiderUserId(req);
    } catch (error) {
      return sendApiError(res, error);
    }
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Rider earnings are temporarily unavailable.',
        },
      });
    }

    try {
      await requireActiveRider(databasePool, riderUserId);
      const result = await databasePool.query(
        `SELECT
           COALESCE(SUM(payout_minor) FILTER (
             WHERE delivered_at >= (
               date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata')
               AT TIME ZONE 'Asia/Kolkata'
             )
           ), 0)::text AS "todayPayoutMinor",
           COUNT(*) FILTER (
             WHERE delivered_at >= (
               date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata')
               AT TIME ZONE 'Asia/Kolkata'
             )
           )::int AS "todayDeliveries",
           COALESCE(SUM(payout_minor), 0)::text AS "lifetimePayoutMinor",
           COUNT(*)::int AS "lifetimeDeliveries"
         FROM app.rider_delivery_earnings
         WHERE rider_id = $1`,
        [riderUserId],
      );
      return res.status(200).json({
        data: { summary: result.rows[0] },
      });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.post('/rider/location', async (req, res, next) => {
    if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
      return sendApiError(
        res,
        new ApiError(
          422,
          'LOCATION_REQUIRED',
          'A valid latitude, longitude, accuracy, and capturedAt are required.',
        ),
      );
    }
    const bodyError = validateObjectBody(
      req.body,
      new Set(['latitude', 'longitude', 'accuracy', 'capturedAt']),
    );
    if (bodyError) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: bodyError },
      });
    }
    let locationFix;
    const serverNow = now();
    try {
      locationFix = validateLocationFix(req.body, serverNow);
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      throw error;
    }
    let riderUserId;
    try {
      riderUserId = getRiderUserId(req);
    } catch (error) {
      return sendApiError(res, error);
    }
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Rider location is temporarily unavailable.',
        },
      });
    }

    try {
      const rider = await requireActiveRider(databasePool, riderUserId);
      if (!rider.is_online && !getRiderDutyStatus(serverNow).open) {
        return sendApiError(
          res,
          new ApiError(
            403,
            'RIDER_OUTSIDE_HOURS',
            'Riders may go online only between 7:00 AM and 10:00 PM.',
            { opensAt: RIDER_HOURS.open },
          ),
        );
      }
      const location = await withTransaction(databasePool, async (client) => {
        await requireActiveRider(client, riderUserId, { forUpdate: true });
        const result = await client.query(
          `UPDATE app.riders AS r
           SET current_latitude = $2,
               current_longitude = $3,
               current_location_accuracy = $4,
               current_location_updated_at = $6::timestamptz,
               is_online = CASE
                 WHEN $5 OR EXISTS (
                   SELECT 1 FROM app.orders AS active_order
                   WHERE active_order.rider_id = r.user_id
                     AND active_order.status IN ('out_for_delivery', 'picked_up')
                 ) THEN true
                 ELSE r.is_online
               END,
               updated_at = now()
           FROM app.users AS u
           WHERE r.user_id = $1
             AND u.id = r.user_id
             AND r.status = 'active'
             AND u.system_role = 'rider'
             AND u.status = 'active'
           RETURNING r.user_id AS "riderId",
                     r.current_latitude AS latitude,
                     r.current_longitude AS longitude,
                     r.current_location_accuracy AS accuracy,
                     r.current_location_updated_at AS "locationUpdatedAt",
                     r.is_online AS "isOnline",
                     r.updated_at AS "updatedAt"`,
          [
            riderUserId,
            locationFix.latitude,
            locationFix.longitude,
            locationFix.accuracy,
            getRiderDutyStatus(serverNow).open,
            locationFix.capturedAt,
          ],
        );
        if (result.rows.length === 0) {
          throw new ApiError(
            403,
            'RIDER_NOT_ALLOWED',
            'The rider account is not active.',
          );
        }
        return result.rows[0];
      });
      return res.status(200).json({ data: { location } });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  return router;
}

module.exports = { createRiderRouter };
