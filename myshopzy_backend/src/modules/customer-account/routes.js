const { randomUUID } = require('node:crypto');
const express = require('express');
const {
  LedgerError,
  addDispute,
  getOutstandingMinor,
  listDues,
  withLedgerTransaction,
} = require('../dues/ledger');
const {
  InvalidCoordinatesError,
  validateCoordinates,
} = require('../delivery-fee/distance');
const { computeDeliveryFeeMinor } = require('../delivery-fee/pricing');

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PARCEL_TYPES = new Set([
  'Documents',
  'Food',
  'Clothing',
  'Electronics',
  'Other',
]);
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function sendError(res, error) {
  const body = { code: error.code, message: error.message };
  if (error.details !== undefined) body.details = error.details;
  res.status(error.status).json({
    error: body,
  });
}

function sendDatabaseUnavailable(res) {
  res.status(503).json({
    error: {
      code: 'DATABASE_UNAVAILABLE',
      message: 'The customer service is temporarily unavailable.',
    },
  });
}

function parseObjectBody(body, allowedKeys) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'Request body must be a JSON object.' };
  }
  const unknownKey = Object.keys(body).find((key) => !allowedKeys.has(key));
  if (unknownKey) return { error: `Unsupported request field: ${unknownKey}.` };
  return { value: body };
}

function parseText(value, field, { minLength = 1, maxLength = 100 } = {}) {
  if (typeof value !== 'string') return { error: `${field} must be a string.` };
  const normalized = value.trim();
  if (normalized.length < minLength || normalized.length > maxLength) {
    return {
      error: `${field} must be between ${minLength} and ${maxLength} characters.`,
    };
  }
  return { value: normalized };
}

function parseAddress(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { error: 'address must be a JSON object.' };
  }
  const serialized = JSON.stringify(value);
  if (!serialized || serialized === '{}' || Buffer.byteLength(serialized) > 4096) {
    return { error: 'address must be a non-empty object of at most 4096 bytes.' };
  }
  return { value: serialized };
}

function parseUuid(value, field) {
  if (typeof value !== 'string' || !UUID_PATTERN.test(value)) {
    return { error: `${field} must be a valid UUID.` };
  }
  return { value };
}

function parsePagination(query) {
  const limitText = query.limit === undefined ? null : query.limit;
  const offsetText = query.offset === undefined ? null : query.offset;
  if (
    (limitText !== null && (typeof limitText !== 'string' || !/^\d{1,3}$/.test(limitText))) ||
    (offsetText !== null &&
      (typeof offsetText !== 'string' || !/^\d{1,16}$/.test(offsetText)))
  ) {
    return { error: 'limit and offset must be non-negative decimal integers.' };
  }

  const limit = limitText === null ? DEFAULT_LIMIT : Number(limitText);
  const offset = offsetText === null ? 0 : Number(offsetText);
  if (!Number.isInteger(limit) || limit < 1 || limit > MAX_LIMIT) {
    return { error: `limit must be between 1 and ${MAX_LIMIT}.` };
  }
  if (!Number.isSafeInteger(offset)) {
    return { error: 'offset must be a safe integer.' };
  }
  return { value: { limit, offset } };
}

function customerIdFromRequest(req) {
  const customerUserId = req.auth?.customerUserId;
  if (typeof customerUserId !== 'string' || !UUID_PATTERN.test(customerUserId)) {
    throw new ApiError(
      401,
      'AUTHENTICATION_REQUIRED',
      'Customer authentication is required.',
    );
  }
  return customerUserId;
}

function requireCustomerAuthentication(databasePool, authenticateCustomer) {
  return (req, res, next) => {
    if (!authenticateCustomer) {
      return res.status(401).json({
        error: {
          code: 'AUTHENTICATION_REQUIRED',
          message: 'Customer authentication is required.',
        },
      });
    }
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const result = authenticateCustomer(req, res, next);
      if (result && typeof result.catch === 'function') {
        result.catch(next);
      }
      return result;
    } catch (error) {
      return next(error);
    }
  };
}

function activeCustomerPredicate(userParam = '$1') {
  return `EXISTS (
    SELECT 1
    FROM app.customers AS c
    JOIN app.users AS u ON u.id = c.user_id
    WHERE c.user_id = ${userParam}
      AND u.system_role = 'customer'
      AND u.status = 'active'
  )`;
}

async function findSavedAddress(databasePool, customerUserId, addressId) {
  const result = await databasePool.query(
    `SELECT id, label, address_snapshot, created_at, updated_at
     FROM app.customer_saved_addresses
     WHERE id = $1 AND customer_user_id = $2
       AND ${activeCustomerPredicate('$2')}`,
    [addressId, customerUserId],
  );
  return result.rows[0] ?? null;
}

function createCustomerAccountRouter({
  databasePool,
  authenticateCustomer = null,
  deliveryDistanceClient = null,
}) {
  const router = express.Router();
  const customerAuth = requireCustomerAuthentication(
    databasePool,
    authenticateCustomer,
  );

  router.use('/me', customerAuth);
  router.use('/me', (req, res, next) => {
    try {
      req.customerUserId = customerIdFromRequest(req);
      next();
    } catch (error) {
      sendError(res, error);
    }
  });

  router.get('/me/dues', async (req, res, next) => {
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const dues = await withLedgerTransaction(databasePool, async (client) => ({
        outstandingMinor: (
          await getOutstandingMinor(client, req.customerUserId)
        ).toString(),
        entries: await listDues(client, {
          customerUserId: req.customerUserId,
          limit: 100,
          offset: 0,
        }),
      }));
      return res.status(200).json({
        data: {
          outstandingMinor: dues.outstandingMinor,
          entries: dues.entries.map((entry) => ({
            entryId: entry.id,
            orderId: entry.order_id,
            reason: entry.reason,
            status: entry.status,
            amountMinor: entry.amount_minor,
            disputes: entry.disputes,
          })),
        },
      });
    } catch (error) {
      return next(error);
    }
  });

  router.post('/me/dues/:entryId/dispute', async (req, res, next) => {
    if (!UUID_PATTERN.test(req.params.entryId)) {
      return sendError(
        res,
        new ApiError(400, 'INVALID_REQUEST', 'entryId must be a valid UUID.'),
      );
    }
    const body = parseObjectBody(req.body, new Set(['message']));
    if (body.error) {
      return sendError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
    }
    const message =
      typeof body.value.message === 'string' ? body.value.message.trim() : '';
    if (message.length < 1 || message.length > 500) {
      return sendError(
        res,
        new ApiError(400, 'INVALID_REQUEST', 'message is required and must be at most 500 characters.'),
      );
    }
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const entry = await withLedgerTransaction(databasePool, (client) =>
        addDispute(client, {
          dueEntryId: req.params.entryId,
          customerUserId: req.customerUserId,
          message,
        }),
      );
      return res.status(201).json({ data: { entry } });
    } catch (error) {
      if (error instanceof LedgerError) return sendError(res, error);
      return next(error);
    }
  });

  router.get('/me/profile', async (req, res, next) => {
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const result = await databasePool.query(
        `SELECT u.id, u.display_name, u.email, u.phone, u.created_at
         FROM app.users AS u
         JOIN app.customers AS c ON c.user_id = u.id
         WHERE u.id = $1
           AND u.system_role = 'customer'
           AND u.status = 'active'`,
        [req.customerUserId],
      );
      if (result.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'CUSTOMER_NOT_FOUND', message: 'Customer not found.' },
        });
      }
      return res.status(200).json({ data: result.rows[0] });
    } catch (error) {
      return next(error);
    }
  });

  router.patch('/me/profile', async (req, res, next) => {
    const body = parseObjectBody(
      req.body,
      new Set(['displayName', 'email', 'phone']),
    );
    if (body.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
    const keys = Object.keys(body.value);
    if (keys.length === 0) {
      return sendError(
        res,
        new ApiError(400, 'INVALID_REQUEST', 'Provide at least one profile field.'),
      );
    }

    const values = {};
    if ('displayName' in body.value) {
      const field = parseText(body.value.displayName, 'displayName', {
        maxLength: 100,
      });
      if (field.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', field.error));
      values.display_name = field.value;
    }
    if ('email' in body.value) {
      const email = body.value.email;
      if (
        email !== null &&
        (typeof email !== 'string' ||
          email.trim().length > 254 ||
          !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()))
      ) {
        return sendError(
          res,
          new ApiError(400, 'INVALID_REQUEST', 'email must be a valid email address or null.'),
        );
      }
      values.email = email === null ? null : email.trim();
    }
    if ('phone' in body.value) {
      const phone = body.value.phone;
      if (
        phone !== null &&
        (typeof phone !== 'string' || !/^\+?[0-9 ()-]{5,32}$/.test(phone.trim()))
      ) {
        return sendError(
          res,
          new ApiError(400, 'INVALID_REQUEST', 'phone must be a valid phone number or null.'),
        );
      }
      values.phone = phone === null ? null : phone.trim();
    }
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const currentProfile = await databasePool.query(
        `SELECT u.email, u.phone
         FROM app.users AS u
         JOIN app.customers AS c ON c.user_id = u.id
         WHERE u.id = $1
           AND u.system_role = 'customer'
           AND u.status = 'active'`,
        [req.customerUserId],
      );
      if (currentProfile.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'CUSTOMER_NOT_FOUND', message: 'Customer not found.' },
        });
      }
      const nextEmail = Object.hasOwn(values, 'email')
        ? values.email
        : currentProfile.rows[0].email;
      const nextPhone = Object.hasOwn(values, 'phone')
        ? values.phone
        : currentProfile.rows[0].phone;
      if (nextEmail === null && nextPhone === null) {
        return sendError(
          res,
          new ApiError(
            400,
            'INVALID_REQUEST',
            'A profile must retain at least one email address or phone number.',
          ),
        );
      }

      const result = await databasePool.query(
        `UPDATE app.users AS u
         SET display_name = COALESCE($2, u.display_name),
             email = CASE WHEN $3::boolean THEN $4::text ELSE u.email END,
             phone = CASE WHEN $5::boolean THEN $6::text ELSE u.phone END,
             updated_at = now()
         WHERE u.id = $1
           AND u.system_role = 'customer'
           AND u.status = 'active'
           AND EXISTS (
             SELECT 1 FROM app.customers AS c WHERE c.user_id = u.id
           )
           AND (
             CASE WHEN $3::boolean THEN $4::text ELSE u.email END IS NOT NULL
             OR CASE WHEN $5::boolean THEN $6::text ELSE u.phone END IS NOT NULL
           )
         RETURNING u.id, u.display_name, u.email, u.phone, u.created_at`,
        [
          req.customerUserId,
          values.display_name ?? null,
          Object.hasOwn(values, 'email'),
          values.email ?? null,
          Object.hasOwn(values, 'phone'),
          values.phone ?? null,
        ],
      );
      if (result.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'CUSTOMER_NOT_FOUND', message: 'Customer not found.' },
        });
      }
      return res.status(200).json({ data: result.rows[0] });
    } catch (error) {
      if (error.code === '23505') {
        return sendError(
          res,
          new ApiError(409, 'PROFILE_CONFLICT', 'Email or phone is already in use.'),
        );
      }
      return next(error);
    }
  });

  router.get('/me/addresses', async (req, res, next) => {
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const result = await databasePool.query(
        `SELECT a.id, a.label, a.address_snapshot, a.created_at, a.updated_at
         FROM app.customer_saved_addresses AS a
         JOIN app.customers AS c ON c.user_id = a.customer_user_id
         JOIN app.users AS u ON u.id = c.user_id
         WHERE a.customer_user_id = $1
           AND u.system_role = 'customer'
           AND u.status = 'active'
         ORDER BY a.created_at, a.id`,
        [req.customerUserId],
      );
      return res.status(200).json({ data: result.rows });
    } catch (error) {
      return next(error);
    }
  });

  router.post('/me/addresses', async (req, res, next) => {
    const body = parseObjectBody(req.body, new Set(['label', 'address']));
    if (body.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
    const label = parseText(body.value.label, 'label', { maxLength: 40 });
    const address = parseAddress(body.value.address);
    if (label.error || address.error) {
      return sendError(
        res,
        new ApiError(400, 'INVALID_REQUEST', label.error || address.error),
      );
    }
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const result = await databasePool.query(
        `INSERT INTO app.customer_saved_addresses
           (id, customer_user_id, label, address_snapshot)
         SELECT $1, c.user_id, $3, $4::jsonb
         FROM app.customers AS c
         JOIN app.users AS u ON u.id = c.user_id
         WHERE c.user_id = $2
           AND u.system_role = 'customer'
           AND u.status = 'active'
         RETURNING id, label, address_snapshot, created_at, updated_at`,
        [randomUUID(), req.customerUserId, label.value, address.value],
      );
      if (result.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'CUSTOMER_NOT_FOUND', message: 'Customer not found.' },
        });
      }
      return res.status(201).json({ data: result.rows[0] });
    } catch (error) {
      return next(error);
    }
  });

  router.patch('/me/addresses/:addressId', async (req, res, next) => {
    const id = parseUuid(req.params.addressId, 'addressId');
    if (id.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', id.error));
    const body = parseObjectBody(req.body, new Set(['label', 'address']));
    if (body.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
    if (Object.keys(body.value).length === 0) {
      return sendError(
        res,
        new ApiError(400, 'INVALID_REQUEST', 'Provide a label or address to update.'),
      );
    }

    let labelValue = null;
    let addressValue = null;
    if (Object.hasOwn(body.value, 'label')) {
      const label = parseText(body.value.label, 'label', { maxLength: 40 });
      if (label.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', label.error));
      labelValue = label.value;
    }
    if (Object.hasOwn(body.value, 'address')) {
      const address = parseAddress(body.value.address);
      if (address.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', address.error));
      addressValue = address.value;
    }
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const result = await databasePool.query(
        `UPDATE app.customer_saved_addresses AS a
         SET label = COALESCE($3, a.label),
             address_snapshot = COALESCE($4::jsonb, a.address_snapshot),
             updated_at = now()
         WHERE a.id = $1
           AND a.customer_user_id = $2
           AND ${activeCustomerPredicate('$2')}
         RETURNING a.id, a.label, a.address_snapshot, a.created_at, a.updated_at`,
        [id.value, req.customerUserId, labelValue, addressValue],
      );
      if (result.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'ADDRESS_NOT_FOUND', message: 'Address not found.' },
        });
      }
      return res.status(200).json({ data: result.rows[0] });
    } catch (error) {
      return next(error);
    }
  });

  router.delete('/me/addresses/:addressId', async (req, res, next) => {
    const id = parseUuid(req.params.addressId, 'addressId');
    if (id.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', id.error));
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const result = await databasePool.query(
        `DELETE FROM app.customer_saved_addresses AS a
         WHERE a.id = $1
           AND a.customer_user_id = $2
           AND ${activeCustomerPredicate('$2')}
         RETURNING a.id`,
        [id.value, req.customerUserId],
      );
      if (result.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'ADDRESS_NOT_FOUND', message: 'Address not found.' },
        });
      }
      return res.status(204).end();
    } catch (error) {
      return next(error);
    }
  });

  router.get('/me/wishlist', async (req, res, next) => {
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const result = await databasePool.query(
        `SELECT
           wi.product_id,
           wi.created_at AS saved_at,
           p.shop_id,
           p.name,
           p.description,
           p.price_minor::text AS price_minor,
           p.currency,
           p.is_available,
           (p.status = 'active'
             AND p.is_available
             AND s.status = 'active'
             AND partner.status = 'approved') AS available,
           s.name AS shop_name
         FROM app.customer_wishlist_items AS wi
         JOIN app.customers AS c ON c.user_id = wi.customer_user_id
         JOIN app.users AS u ON u.id = c.user_id
         JOIN app.products AS p
           ON p.id = wi.product_id
          AND p.shop_id = wi.shop_id
          AND p.partner_id = wi.partner_id
         JOIN app.shops AS s ON s.id = p.shop_id AND s.partner_id = p.partner_id
         JOIN app.partners AS partner ON partner.id = p.partner_id
         WHERE wi.customer_user_id = $1
           AND u.system_role = 'customer'
           AND u.status = 'active'
         ORDER BY wi.created_at DESC, wi.product_id`,
        [req.customerUserId],
      );
      return res.status(200).json({ data: result.rows });
    } catch (error) {
      return next(error);
    }
  });

  router.post('/me/wishlist/items', async (req, res, next) => {
    const body = parseObjectBody(req.body, new Set(['productId']));
    if (body.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
    const productId = parseUuid(body.value.productId, 'productId');
    if (productId.error) {
      return sendError(res, new ApiError(400, 'INVALID_REQUEST', productId.error));
    }
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const result = await databasePool.query(
        `INSERT INTO app.customer_wishlist_items
           (customer_user_id, product_id, shop_id, partner_id)
         SELECT c.user_id, p.id, p.shop_id, p.partner_id
         FROM app.customers AS c
         JOIN app.users AS u ON u.id = c.user_id
         JOIN app.products AS p ON p.id = $2
         JOIN app.shops AS s
           ON s.id = p.shop_id AND s.partner_id = p.partner_id
         JOIN app.partners AS partner ON partner.id = p.partner_id
         WHERE c.user_id = $1
           AND u.system_role = 'customer'
           AND u.status = 'active'
           AND p.status = 'active'
           AND p.is_available = true
           AND s.status = 'active'
           AND partner.status = 'approved'
         ON CONFLICT (customer_user_id, product_id) DO NOTHING
         RETURNING product_id`,
        [req.customerUserId, productId.value],
      );
      if (result.rows.length === 0) {
        const customer = await databasePool.query(
          `SELECT 1
           FROM app.customers AS c
           JOIN app.users AS u ON u.id = c.user_id
           WHERE c.user_id = $1
             AND u.system_role = 'customer'
             AND u.status = 'active'`,
          [req.customerUserId],
        );
        if (customer.rows.length === 0) {
          return res.status(404).json({
            error: { code: 'CUSTOMER_NOT_FOUND', message: 'Customer not found.' },
          });
        }
        const existing = await databasePool.query(
          `SELECT 1 FROM app.customer_wishlist_items
           WHERE customer_user_id = $1 AND product_id = $2`,
          [req.customerUserId, productId.value],
        );
        if (existing.rows.length === 0) {
          return res.status(409).json({
            error: {
              code: 'PRODUCT_UNAVAILABLE',
              message: 'The product is currently unavailable.',
            },
          });
        }
      }
      return res.status(result.rows.length ? 201 : 200).json({
        data: { productId: productId.value, saved: true },
      });
    } catch (error) {
      return next(error);
    }
  });

  router.delete('/me/wishlist/items/:productId', async (req, res, next) => {
    const productId = parseUuid(req.params.productId, 'productId');
    if (productId.error) {
      return sendError(res, new ApiError(400, 'INVALID_REQUEST', productId.error));
    }
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      await databasePool.query(
        `DELETE FROM app.customer_wishlist_items AS wi
         WHERE wi.customer_user_id = $1
           AND wi.product_id = $2
           AND ${activeCustomerPredicate('$1')}`,
        [req.customerUserId, productId.value],
      );
      return res.status(204).end();
    } catch (error) {
      return next(error);
    }
  });

  router.get('/me/orders', async (req, res, next) => {
    const page = parsePagination(req.query);
    if (page.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', page.error));
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const result = await databasePool.query(
        `SELECT
           o.id,
           o.partner_id,
           o.shop_id,
           s.name AS shop_name,
           o.status,
           o.currency,
           o.payment_method,
           CASE WHEN payment.status = 'verified' THEN 'paid'
             ELSE 'pending' END AS payment_status,
           COALESCE(payment.status = 'verified', false) AS payment_verified,
           o.items_subtotal_minor::text AS items_subtotal_minor,
           o.delivery_fee_minor::text AS delivery_fee_minor,
           o.discount_minor::text AS discount_minor,
           o.total_minor::text AS total_minor,
           o.placed_at,
           o.updated_at,
           o.cancellation_reason,
           o.placed_at + interval '2 minutes' AS cancellation_deadline_at,
           statement_timestamp() AS server_now,
           (
             o.status IN ('placed', 'confirmed', 'preparing')
             AND statement_timestamp() < o.placed_at + interval '2 minutes'
           ) AS cancellation_eligible,
           (SELECT count(*)::integer
            FROM app.order_items AS oi
            WHERE oi.order_id = o.id) AS item_count
         FROM app.orders AS o
         JOIN app.customers AS c ON c.user_id = o.customer_user_id
         JOIN app.users AS u ON u.id = c.user_id
         JOIN app.shops AS s
           ON s.id = o.shop_id AND s.partner_id = o.partner_id
         LEFT JOIN app.order_payment_attempts AS payment
           ON payment.order_id = o.id
          AND payment.customer_user_id = o.customer_user_id
         WHERE o.customer_user_id = $1
           AND u.system_role = 'customer'
           AND u.status = 'active'
         ORDER BY o.placed_at DESC, o.id DESC
         LIMIT $2 OFFSET $3`,
        [req.customerUserId, page.value.limit, page.value.offset],
      );
      return res.status(200).json({
        data: result.rows,
        pagination: page.value,
      });
    } catch (error) {
      return next(error);
    }
  });

  router.get('/me/orders/:orderId', async (req, res, next) => {
    const id = parseUuid(req.params.orderId, 'orderId');
    if (id.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', id.error));
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const orderResult = await databasePool.query(
        `SELECT
           o.id,
           o.partner_id,
           o.shop_id,
           s.name AS shop_name,
           o.status,
           o.currency,
           o.payment_method,
           CASE WHEN payment.status = 'verified' THEN 'paid'
             ELSE 'pending' END AS payment_status,
           COALESCE(payment.status = 'verified', false) AS payment_verified,
           o.items_subtotal_minor::text AS items_subtotal_minor,
           o.delivery_fee_minor::text AS delivery_fee_minor,
           o.discount_minor::text AS discount_minor,
           o.total_minor::text AS total_minor,
           o.delivery_address_snapshot,
           o.placed_at,
           o.updated_at,
           o.cancellation_reason,
           o.placed_at + interval '2 minutes' AS cancellation_deadline_at,
           statement_timestamp() AS server_now,
           (
             o.status IN ('placed', 'confirmed', 'preparing')
             AND statement_timestamp() < o.placed_at + interval '2 minutes'
           ) AS cancellation_eligible,
           CASE WHEN rider_user.id IS NULL THEN NULL
             ELSE jsonb_build_object(
               'name', rider_user.display_name,
               'phone', rider_user.phone,
               'latitude', rider.current_latitude,
               'longitude', rider.current_longitude
             )
           END AS rider
         FROM app.orders AS o
         JOIN app.customers AS c ON c.user_id = o.customer_user_id
         JOIN app.users AS u ON u.id = c.user_id
         JOIN app.shops AS s
           ON s.id = o.shop_id AND s.partner_id = o.partner_id
         LEFT JOIN app.order_payment_attempts AS payment
           ON payment.order_id = o.id
          AND payment.customer_user_id = o.customer_user_id
         LEFT JOIN app.riders AS rider
           ON rider.user_id = o.rider_id AND rider.status = 'active'
         LEFT JOIN app.users AS rider_user
           ON rider_user.id = rider.user_id
           AND rider_user.system_role = 'rider'
           AND rider_user.status = 'active'
         WHERE o.id = $1
           AND o.customer_user_id = $2
           AND u.system_role = 'customer'
           AND u.status = 'active'`,
        [id.value, req.customerUserId],
      );
      if (orderResult.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'ORDER_NOT_FOUND', message: 'Order not found.' },
        });
      }
      const itemResult = await databasePool.query(
        `SELECT
           product_id,
           product_name_snapshot,
           sku_snapshot,
           unit_price_minor::text AS unit_price_minor,
           quantity,
           line_total_minor::text AS line_total_minor,
           currency,
           variant_snapshot
         FROM app.order_items
         WHERE order_id = $1
         ORDER BY created_at, id`,
        [id.value],
      );
      return res.status(200).json({
        data: { ...orderResult.rows[0], items: itemResult.rows },
      });
    } catch (error) {
      return next(error);
    }
  });

  router.post('/me/orders/:orderId/cancel', async (req, res, next) => {
    const id = parseUuid(req.params.orderId, 'orderId');
    if (id.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', id.error));
    const body = parseObjectBody(req.body, new Set(['reason']));
    if (body.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
    const reason = parseText(body.value.reason, 'reason', { maxLength: 300 });
    if (reason.error) {
      return sendError(res, new ApiError(400, 'INVALID_REQUEST', reason.error));
    }
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const cancellation = await databasePool.query(
        `UPDATE app.orders AS o
         SET status = 'cancelled',
             cancellation_reason = $3,
             updated_at = clock_timestamp()
         WHERE o.id = $1
           AND o.customer_user_id = $2
           AND o.status IN ('placed', 'confirmed', 'preparing')
           AND o.placed_at + interval '2 minutes' > clock_timestamp()
           AND EXISTS (
             SELECT 1
             FROM app.customers AS c
             JOIN app.users AS u ON u.id = c.user_id
             WHERE c.user_id = o.customer_user_id
               AND u.system_role = 'customer'
               AND u.status = 'active'
           )
         RETURNING o.id, o.status, o.cancellation_reason, o.placed_at,
                   o.placed_at + interval '2 minutes' AS cancellation_deadline_at,
                   clock_timestamp() AS server_now,
                   false AS cancellation_eligible`,
        [id.value, req.customerUserId, reason.value],
      );
      if (cancellation.rows.length === 1) {
        return res.status(200).json({ data: cancellation.rows[0] });
      }

      const current = await databasePool.query(
        `SELECT o.status, o.placed_at, clock_timestamp() AS server_now
         FROM app.orders AS o
         JOIN app.customers AS c ON c.user_id = o.customer_user_id
         JOIN app.users AS u ON u.id = c.user_id
         WHERE o.id = $1
           AND o.customer_user_id = $2
           AND u.system_role = 'customer'
           AND u.status = 'active'`,
        [id.value, req.customerUserId],
      );
      if (current.rows.length === 0) {
        return sendError(
          res,
          new ApiError(404, 'ORDER_NOT_FOUND', 'Order not found.'),
        );
      }
      const order = current.rows[0];
      if (
        ['placed', 'confirmed', 'preparing'].includes(order.status) &&
        new Date(order.placed_at).getTime() + 120_000 <=
          new Date(order.server_now).getTime()
      ) {
        return sendError(
          res,
          new ApiError(
            409,
            'CANCELLATION_WINDOW_CLOSED',
            'The cancellation window has closed.',
          ),
        );
      }
      return sendError(
        res,
        new ApiError(
          409,
          'ORDER_NOT_CANCELLABLE',
          'This order can no longer be cancelled.',
        ),
      );
    } catch (error) {
      return next(error);
    }
  });

  router.get('/me/parcels', async (req, res, next) => {
    const page = parsePagination(req.query);
    if (page.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', page.error));
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const result = await databasePool.query(
        `SELECT id, pickup_location, drop_location, parcel_type,
                weight_grams, instructions, status, created_at, updated_at,
                pickup_latitude, pickup_longitude, drop_latitude,
                drop_longitude, delivery_distance_m, delivery_fee_minor,
                delivery_fee_kind
         FROM app.parcel_bookings
         WHERE customer_user_id = $1
           AND ${activeCustomerPredicate('$1')}
         ORDER BY created_at DESC, id DESC
         LIMIT $2 OFFSET $3`,
        [req.customerUserId, page.value.limit, page.value.offset],
      );
      return res.status(200).json({
        data: result.rows,
        pagination: page.value,
      });
    } catch (error) {
      return next(error);
    }
  });

  router.post('/me/parcels', async (req, res, next) => {
    const body = parseObjectBody(
      req.body,
      new Set([
        'pickupLocation',
        'dropLocation',
        'parcelType',
        'weightKg',
        'instructions',
        'pickupLatitude',
        'pickupLongitude',
        'dropLatitude',
        'dropLongitude',
        'deliveryFeeMinor',
        'distanceMeters',
        'deliveryDistanceM',
        'delivery_fee_minor',
        'delivery_distance_m',
        'distanceM',
        'distance_m',
      ]),
    );
    if (body.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
    const pickup = parseText(body.value.pickupLocation, 'pickupLocation', {
      maxLength: 300,
    });
    const drop = parseText(body.value.dropLocation, 'dropLocation', {
      maxLength: 300,
    });
    const parcelType =
      typeof body.value.parcelType === 'string' &&
      PARCEL_TYPES.has(body.value.parcelType)
        ? { value: body.value.parcelType }
        : { error: 'parcelType is not supported.' };
    const weightKg = body.value.weightKg;
    if (
      typeof weightKg !== 'number' ||
      !Number.isFinite(weightKg) ||
      weightKg <= 0 ||
      weightKg > 20 ||
      Math.abs(weightKg * 1000 - Math.round(weightKg * 1000)) > 1e-7
    ) {
      return sendError(
        res,
        new ApiError(400, 'INVALID_REQUEST', 'weightKg must be between 0 and 20 with up to 3 decimals.'),
      );
    }
    const instructions =
      body.value.instructions === undefined
        ? { value: '' }
        : parseText(body.value.instructions, 'instructions', {
            minLength: 0,
            maxLength: 1000,
          });
    const validationError =
      pickup.error || drop.error || parcelType.error || instructions.error;
    if (validationError) {
      return sendError(res, new ApiError(400, 'INVALID_REQUEST', validationError));
    }
    const coordinateNames = [
      'pickupLatitude',
      'pickupLongitude',
      'dropLatitude',
      'dropLongitude',
    ];
    if (coordinateNames.some((name) => body.value[name] === undefined)) {
      return sendError(
        res,
        new ApiError(
          422,
          'ADDRESS_LOCATION_REQUIRED',
          'Pickup and drop coordinates are required to price a parcel.',
        ),
      );
    }
    let pickupCoordinates;
    let dropCoordinates;
    try {
      pickupCoordinates = validateCoordinates({
        latitude: body.value.pickupLatitude,
        longitude: body.value.pickupLongitude,
      });
      dropCoordinates = validateCoordinates({
        latitude: body.value.dropLatitude,
        longitude: body.value.dropLongitude,
      });
    } catch (error) {
      if (error instanceof InvalidCoordinatesError) {
        return sendError(
          res,
          new ApiError(422, 'ADDRESS_LOCATION_INVALID', error.message),
        );
      }
      throw error;
    }
    if (!databasePool) return sendDatabaseUnavailable(res);
    if (!deliveryDistanceClient) {
      return sendError(
        res,
        new ApiError(
          503,
          'DISTANCE_UNAVAILABLE',
          'Parcel distance could not be verified.',
        ),
      );
    }
    let deliveryDistanceM;
    try {
      deliveryDistanceM = await deliveryDistanceClient.getRoadDistanceMetres(
        pickupCoordinates,
        dropCoordinates,
      );
    } catch {
      return sendError(
        res,
        new ApiError(
          503,
          'DISTANCE_UNAVAILABLE',
          'Parcel distance could not be verified.',
        ),
      );
    }
    if (!Number.isSafeInteger(deliveryDistanceM) || deliveryDistanceM < 0) {
      return sendError(
        res,
        new ApiError(
          503,
          'DISTANCE_UNAVAILABLE',
          'Parcel distance could not be verified.',
        ),
      );
    }
    let deliveryFeeMinor;
    try {
      deliveryFeeMinor = computeDeliveryFeeMinor('parcel', deliveryDistanceM);
    } catch {
      return sendError(
        res,
        new ApiError(
          503,
          'DISTANCE_UNAVAILABLE',
          'Parcel distance could not be verified.',
        ),
      );
    }
    try {
      const result = await databasePool.query(
        `INSERT INTO app.parcel_bookings (
           id, customer_user_id, pickup_location, drop_location, parcel_type,
           weight_grams, instructions, pickup_latitude, pickup_longitude,
           drop_latitude, drop_longitude, delivery_distance_m,
           delivery_fee_minor, delivery_fee_kind
         )
         SELECT $1, $2::uuid, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, 'parcel'
         WHERE EXISTS (
           SELECT 1
           FROM app.customers AS c
           JOIN app.users AS u ON u.id = c.user_id
           WHERE c.user_id = $2::uuid
             AND u.system_role = 'customer'
             AND u.status = 'active'
         )
         RETURNING id, pickup_location, drop_location, parcel_type,
                   weight_grams, instructions, status, created_at,
                   pickup_latitude, pickup_longitude, drop_latitude,
                   drop_longitude, delivery_distance_m, delivery_fee_minor,
                   delivery_fee_kind`,
        [
          randomUUID(),
          req.customerUserId,
          pickup.value,
          drop.value,
          parcelType.value,
          Math.round(weightKg * 1000),
          instructions.value,
          pickupCoordinates.latitude,
          pickupCoordinates.longitude,
          dropCoordinates.latitude,
          dropCoordinates.longitude,
          deliveryDistanceM,
          deliveryFeeMinor,
        ],
      );
      if (result.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'CUSTOMER_NOT_FOUND', message: 'Customer not found.' },
        });
      }
      return res.status(201).json({ data: result.rows[0] });
    } catch (error) {
      return next(error);
    }
  });

  router.get('/me/parcels/:parcelId', async (req, res, next) => {
    const id = parseUuid(req.params.parcelId, 'parcelId');
    if (id.error) return sendError(res, new ApiError(400, 'INVALID_REQUEST', id.error));
    if (!databasePool) return sendDatabaseUnavailable(res);
    try {
      const result = await databasePool.query(
        `SELECT id, pickup_location, drop_location, parcel_type,
                weight_grams, instructions, status, created_at, updated_at,
                pickup_latitude, pickup_longitude, drop_latitude,
                drop_longitude, delivery_distance_m, delivery_fee_minor,
                delivery_fee_kind
         FROM app.parcel_bookings
         WHERE id = $1
           AND customer_user_id = $2
           AND ${activeCustomerPredicate('$2')}`,
        [id.value, req.customerUserId],
      );
      if (result.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'PARCEL_NOT_FOUND', message: 'Parcel booking not found.' },
        });
      }
      return res.status(200).json({ data: result.rows[0] });
    } catch (error) {
      return next(error);
    }
  });

  return router;
}

module.exports = { createCustomerAccountRouter };
