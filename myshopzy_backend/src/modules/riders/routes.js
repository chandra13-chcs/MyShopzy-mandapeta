const express = require('express');
const { createPendingDue } = require('../dues/ledger');
const { DUE_POLICY } = require('../dues/policy');

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const RIDER_STATUSES = new Set(['picked_up', 'out_for_delivery', 'delivered']);
const DELIVERY_FAILURE_REASONS = new Set([
  'customer_refused',
  'customer_unreachable',
  'wrong_address_by_customer',
]);

class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function sendApiError(res, error) {
  return res.status(error.status).json({
    error: { code: error.code, message: error.message },
  });
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

async function requireActiveRider(queryable, riderUserId, { lock = false } = {}) {
  const result = await queryable.query(
    `SELECT r.user_id, r.is_online
     FROM app.riders AS r
     JOIN app.users AS u ON u.id = r.user_id
     WHERE r.user_id = $1
       AND r.status = 'active'
       AND u.system_role = 'rider'
       AND u.status = 'active'
     ${lock ? 'FOR SHARE OF r, u' : ''}`,
    [riderUserId],
  );
  if (result.rows.length === 0) {
    throw new ApiError(403, 'RIDER_NOT_ALLOWED', 'The rider account is not active.');
  }
  return result.rows[0].is_online === true;
}

function createRiderRouter({ databasePool = null, authenticateRider = null } = {}) {
  const router = express.Router();
  router.use('/rider', requireRiderAuthentication(authenticateRider));

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
      const isOnline = await requireActiveRider(databasePool, riderUserId);
      if (!isOnline) {
        return res.status(403).json({
          error: { code: 'RIDER_OFFLINE', message: 'Rider is offline.' },
        });
      }
      const result = await databasePool.query(
        `SELECT
           o.id AS "orderId",
           o.status,
           o.shop_id AS "shopId",
           s.name AS store,
           cu.display_name AS "customerName",
           s.address AS pickup,
           o.delivery_address_snapshot AS "drop",
           o.currency,
           o.items_subtotal_minor::text AS "itemsSubtotalMinor",
           o.delivery_fee_minor::text AS "deliveryFeeMinor",
           (o.delivery_fee_minor::numeric / 100)::numeric(12, 2) AS payout,
           o.total_minor::text AS "totalMinor",
           o.placed_at AS "placedAt",
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
         JOIN app.users AS cu ON cu.id = o.customer_user_id
         WHERE o.status = 'getting_packed'
           AND o.rider_id IS NULL
           AND EXISTS (
             SELECT 1
             FROM app.riders AS online_rider
             JOIN app.users AS online_user
               ON online_user.id = online_rider.user_id
             WHERE online_rider.user_id = $1
               AND online_rider.is_online = true
               AND online_rider.status = 'active'
               AND online_user.system_role = 'rider'
               AND online_user.status = 'active'
           )
         ORDER BY o.placed_at ASC, o.id ASC`,
        [riderUserId],
      );
      return res.status(200).json({ data: { orders: result.rows } });
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
        const isOnline = await requireActiveRider(client, riderUserId, {
          lock: true,
        });
        if (!isOnline) {
          throw new ApiError(403, 'RIDER_OFFLINE', 'Rider is offline');
        }
        const current = await client.query(
          `SELECT id, status, rider_id
           FROM app.orders
           WHERE id = $1
           FOR UPDATE`,
          [req.params.orderId],
        );
        if (current.rows.length === 0) {
          throw new ApiError(404, 'ORDER_NOT_FOUND', 'Order not found.');
        }
        if (
          current.rows[0].status !== 'getting_packed' ||
          current.rows[0].rider_id !== null
        ) {
          throw new ApiError(
            409,
            'ORDER_NOT_AVAILABLE',
            'This order is no longer available.',
          );
        }

        const accepted = await client.query(
          `UPDATE app.orders
           SET rider_id = $2,
               status = 'out_for_delivery',
               rider_stage = 'accepted',
               updated_at = now()
           WHERE id = $1
             AND status = 'getting_packed'
             AND rider_id IS NULL
           RETURNING id AS "orderId", status, rider_id AS "riderId",
                     updated_at AS "updatedAt"`,
          [req.params.orderId, riderUserId],
        );
        if (accepted.rows.length === 0) {
          throw new ApiError(
            409,
            'ORDER_NOT_AVAILABLE',
            'This order is no longer available.',
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
      if (
        error instanceof ApiError &&
        ['RIDER_OFFLINE', 'RIDER_NOT_ALLOWED'].includes(error.code)
      ) {
        return res.status(error.status).json({
          success: false,
          message: 'Rider is offline',
        });
      }
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
                     delivery_fee_minor AS "payoutMinor",
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
          await client.query(
            `INSERT INTO app.rider_delivery_earnings
               (order_id, rider_id, payout_minor, currency)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (order_id) DO NOTHING`,
            [
              result.rows[0].orderId,
              riderUserId,
              result.rows[0].payoutMinor,
              result.rows[0].currency,
            ],
          );
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
    const bodyError = validateObjectBody(req.body, new Set(['isOnline']));
    if (bodyError || typeof req.body.isOnline !== 'boolean') {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: bodyError ?? 'isOnline must be a boolean.',
        },
      });
    }
    if (req.body.isOnline) {
      return res.status(409).json({
        error: {
          code: 'LOCATION_REQUIRED',
          message: 'Share a valid location to go online.',
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
          message: 'Rider availability is temporarily unavailable.',
        },
      });
    }

    try {
      const result = await databasePool.query(
        `UPDATE app.riders AS r
         SET is_online = false, updated_at = now()
         FROM app.users AS u
         WHERE r.user_id = $1
           AND u.id = r.user_id
           AND r.status = 'active'
           AND u.system_role = 'rider'
           AND u.status = 'active'
         RETURNING r.is_online AS "isOnline"`,
        [riderUserId],
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
    const bodyError = validateObjectBody(
      req.body,
      new Set(['latitude', 'longitude']),
    );
    if (bodyError) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: bodyError },
      });
    }
    const { latitude, longitude } = req.body;
    if (
      typeof latitude !== 'number' ||
      !Number.isFinite(latitude) ||
      latitude < -90 ||
      latitude > 90
    ) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'latitude must be a finite number between -90 and 90.',
        },
      });
    }
    if (
      typeof longitude !== 'number' ||
      !Number.isFinite(longitude) ||
      longitude < -180 ||
      longitude > 180
    ) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'longitude must be a finite number between -180 and 180.',
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
          message: 'Rider location is temporarily unavailable.',
        },
      });
    }

    try {
      const location = await withTransaction(databasePool, async (client) => {
        await requireActiveRider(client, riderUserId, { lock: true });
        const result = await client.query(
          `UPDATE app.riders AS r
           SET current_latitude = $2,
               current_longitude = $3,
               is_online = true,
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
                     r.is_online AS "isOnline",
                     r.updated_at AS "updatedAt"`,
          [riderUserId, latitude, longitude],
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
