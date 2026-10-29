const { createHash, randomBytes, randomUUID } = require('node:crypto');
const express = require('express');
const { formatHoursMessage, isOpenNow } = require('../shared/store-hours');
const {
  computeCommissionMinor,
  resolveCommissionBps,
} = require('../commission/rules');
const { getOutstandingMinor, lockCustomer } = require('../dues/ledger');
const { computeDeliveryFeeMinor } = require('../delivery-fee/pricing');
const { PLATFORM_FEE_MINOR } = require('../delivery-serviceability/pricing');
const {
  validateCoordinates,
} = require('../delivery-fee/distance');
const {
  verifyRazorpaySignature,
} = require('../payments/razorpay-signature');

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CART_TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;
const MAX_QUANTITY = 99;
const MAX_BIGINT = 9223372036854775807n;
const CLIENT_PRICING_FIELDS = new Set([
  'deliveryFeeMinor',
  'distanceMeters',
  'deliveryDistanceM',
  'delivery_fee_minor',
  'delivery_distance_m',
  'distanceM',
  'distance_m',
]);

function omitClientPricingFields(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([key]) => !CLIENT_PRICING_FIELDS.has(key)),
  );
}

function invokeCustomerAuthentication(authenticateCustomer, req, res, next) {
  try {
    const result = authenticateCustomer(req, res, next);
    if (result && typeof result.catch === 'function') result.catch(next);
    return result;
  } catch (error) {
    return next(error);
  }
}

class ApiError extends Error {
  constructor(status, code, message, details = undefined) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function sendApiError(res, error) {
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
      message: 'The cart and checkout service is temporarily unavailable.',
    },
  });
}

function requireCustomerCartOwnership(authenticateCustomer) {
  return (req, res, next) => {
    if (!authenticateCustomer) {
      return sendApiError(
        res,
        new ApiError(
          401,
          'AUTHENTICATION_REQUIRED',
          'Customer authentication is required.',
        ),
      );
    }
    return invokeCustomerAuthentication(
      authenticateCustomer,
      req,
      res,
      () => {
        const customerUserId = req.auth?.customerUserId;
        if (
          typeof customerUserId !== 'string' ||
          !UUID_PATTERN.test(customerUserId)
        ) {
          return sendApiError(
            res,
            new ApiError(
              401,
              'AUTHENTICATION_REQUIRED',
              'Customer authentication is required.',
            ),
          );
        }
        return next();
      },
    );
  };
}

function parseObjectBody(body, allowedKeys) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'Request body must be a JSON object.' };
  }
  const unknownKey = Object.keys(body).find((key) => !allowedKeys.has(key));
  if (unknownKey) {
    return { error: `Unsupported request field: ${unknownKey}.` };
  }
  return { value: body };
}

function parseQuantity(value, { optional = false } = {}) {
  if (optional && value === undefined) return { value: 1 };
  if (!Number.isSafeInteger(value) || value < 1 || value > MAX_QUANTITY) {
    return {
      error: `quantity must be an integer between 1 and ${MAX_QUANTITY}.`,
    };
  }
  return { value };
}

function parseProductId(value) {
  if (typeof value !== 'string' || !UUID_PATTERN.test(value)) {
    return { error: 'productId must be a valid UUID.' };
  }
  return { value };
}

function parseVariantId(value) {
  if (typeof value !== 'string' || !UUID_PATTERN.test(value)) {
    return { error: 'variantId must be a valid UUID.' };
  }
  return { value };
}

function getCartToken(req) {
  const token = req.get('x-cart-token');
  if (typeof token !== 'string' || !CART_TOKEN_PATTERN.test(token)) {
    throw new ApiError(401, 'CART_TOKEN_REQUIRED', 'A valid cart token is required.');
  }
  return token;
}

function hashCartToken(token) {
  return createHash('sha256').update(token).digest();
}

function formatPaymentOrderResult(row, itemCount) {
  return {
    orderId: row.order_id,
    status: row.order_status,
    currency: row.currency.trim(),
    itemSubtotalMinor: row.items_subtotal_minor,
    deliveryFeeMinor: row.delivery_fee_minor,
    discountMinor: row.discount_minor,
    totalMinor: row.total_minor,
    items: itemCount,
    paymentStatus: row.payment_status === 'verified' ? 'paid' : 'pending',
    paymentVerified: row.payment_status === 'verified',
  };
}

function isValidRazorpayOrder(order, { receipt, amountMinor, currency }) {
  return (
    order &&
    typeof order.id === 'string' &&
    order.receipt === receipt &&
    Number(order.amount) === Number(amountMinor) &&
    typeof order.currency === 'string' &&
    order.currency === currency
  );
}

async function ensureRazorpayOrder({
  databasePool,
  razorpayClient,
  razorpayKeyId,
  paymentAttempt,
}) {
  let razorpayOrderId = paymentAttempt.provider_order_id;
  if (!razorpayOrderId) {
    const orders = await razorpayClient.orders.all({
      receipt: paymentAttempt.payment_attempt_id,
      count: 10,
    });
    const receiptOrders = Array.isArray(orders?.items)
      ? orders.items.filter(
          (order) => order?.receipt === paymentAttempt.payment_attempt_id,
        )
      : [];
    const existingOrder = receiptOrders.find((order) =>
      isValidRazorpayOrder(order, {
        receipt: paymentAttempt.payment_attempt_id,
        amountMinor: paymentAttempt.total_minor,
        currency: paymentAttempt.currency.trim(),
      }),
    );
    if (receiptOrders.length > 0 && !existingOrder) {
      throw new ApiError(
        502,
        'PAYMENT_PROVIDER_INVALID_RESPONSE',
        'The payment provider returned an inconsistent order for this checkout.',
      );
    }
    const providerOrder =
      existingOrder ??
      (await razorpayClient.orders.create({
        amount: Number(paymentAttempt.total_minor),
        currency: paymentAttempt.currency.trim(),
        receipt: paymentAttempt.payment_attempt_id,
        notes: { myshopzy_order_id: paymentAttempt.order_id },
      }));
    if (
      !isValidRazorpayOrder(providerOrder, {
        receipt: paymentAttempt.payment_attempt_id,
        amountMinor: paymentAttempt.total_minor,
        currency: paymentAttempt.currency.trim(),
      })
    ) {
      throw new ApiError(
        502,
        'PAYMENT_PROVIDER_INVALID_RESPONSE',
        'The payment provider returned an invalid order.',
      );
    }

    const savedOrder = await databasePool.query(
      `UPDATE app.order_payment_attempts
       SET provider_order_id = $2
       WHERE id = $1
         AND status = 'pending'
         AND (provider_order_id IS NULL OR provider_order_id = $2)
       RETURNING provider_order_id`,
      [paymentAttempt.payment_attempt_id, providerOrder.id],
    );
    if (savedOrder.rows.length === 0) {
      throw new ApiError(
        409,
        'PAYMENT_ORDER_CONFLICT',
        'This checkout is already associated with another payment order.',
      );
    }
    razorpayOrderId = savedOrder.rows[0].provider_order_id;
  }

  return {
    keyId: razorpayKeyId,
    razorpayOrderId,
    amountMinor: paymentAttempt.total_minor,
    currency: paymentAttempt.currency.trim(),
  };
}

async function withTransaction(pool, action) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    try {
      const result = await action(client);
      await client.query('COMMIT');
      return result;
    } catch (error) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        throw new AggregateError(
          [error, rollbackError],
          'Database transaction and rollback both failed.',
        );
      }
      throw error;
    }
  } finally {
    client.release();
  }
}

async function findCart(
  client,
  tokenHash,
  customerUserId,
  { lock = false } = {},
) {
  const result = await client.query(
    `SELECT id, shop_id, partner_id
     FROM app.customer_carts
     WHERE token_hash = $1 AND customer_user_id = $2${lock ? ' FOR UPDATE' : ''}`,
    [tokenHash, customerUserId],
  );
  if (result.rows.length === 0) {
    throw new ApiError(404, 'CART_NOT_FOUND', 'Cart not found.');
  }
  return result.rows[0];
}

async function findProduct(client, productId, { lock = false } = {}) {
  const result = await client.query(
    `SELECT
       p.id,
       p.shop_id,
       p.partner_id,
       p.name,
       p.currency,
       p.is_available,
       p.status AS product_status,
       s.status AS shop_status,
       partner.status AS partner_status
     FROM app.products AS p
     JOIN app.shops AS s
       ON s.id = p.shop_id AND s.partner_id = p.partner_id
     JOIN app.partners AS partner ON partner.id = p.partner_id
     WHERE p.id = $1${lock ? ' FOR UPDATE OF p, s, partner' : ' FOR SHARE OF p, s, partner'}`,
    [productId],
  );
  if (result.rows.length === 0) {
    throw new ApiError(404, 'PRODUCT_NOT_FOUND', 'Product not found.');
  }

  const product = result.rows[0];
  if (
    product.product_status !== 'active' ||
    !product.is_available ||
    product.shop_status !== 'active' ||
    product.partner_status !== 'approved'
  ) {
    throw new ApiError(
      409,
      'PRODUCT_UNAVAILABLE',
      'The product or shop is currently unavailable.',
    );
  }
  return product;
}

async function findVariant(client, product, variantId, { lock = false } = {}) {
  const result = await client.query(
    `SELECT
       id,
       product_id,
       shop_id,
       partner_id,
       label,
       unit,
       quantity,
       price_minor::text AS price_minor,
       stock,
       sku,
       is_available
     FROM app.product_variants
     WHERE id = $1
       AND product_id = $2
       AND shop_id = $3
       AND partner_id = $4${lock ? ' FOR UPDATE' : ' FOR SHARE'}`,
    [variantId, product.id, product.shop_id, product.partner_id],
  );
  if (result.rows.length === 0) {
    throw new ApiError(404, 'VARIANT_NOT_FOUND', 'Product variant not found.');
  }
  const variant = result.rows[0];
  if (!variant.is_available) {
    throw new ApiError(
      409,
      'PRODUCT_UNAVAILABLE',
      'The product or shop is currently unavailable.',
    );
  }
  return variant;
}

function assertStock(item, quantity) {
  if (item.stock !== null && Number(item.stock) < quantity) {
    throw new ApiError(
      409,
      'INSUFFICIENT_STOCK',
      'The requested quantity is not available.',
    );
  }
}

async function readCartItems(client, cartId, { lock = false } = {}) {
  const result = await client.query(
    `SELECT
       ci.product_id,
       ci.variant_id,
       ci.quantity,
       p.shop_id,
       p.partner_id,
       p.name,
       p.currency,
       p.is_available AS product_is_available,
       p.status AS product_status,
       v.label AS variant_label,
       v.unit AS variant_unit,
       v.quantity AS variant_quantity,
       v.sku AS variant_sku,
       v.price_minor::text AS price_minor,
       v.stock AS variant_stock,
       v.is_available AS variant_is_available,
       s.status AS shop_status,
       s.latitude::double precision AS shop_latitude,
       s.longitude::double precision AS shop_longitude,
       s.operating_details,
       partner.timezone,
      partner.status AS partner_status,
      partner.partner_type,
      partner.commission_bps_override AS partner_commission_bps_override,
      category.category_code,
      category.commission_bps_override AS category_commission_bps_override
     FROM app.customer_cart_items AS ci
     JOIN app.products AS p
       ON p.id = ci.product_id
      AND p.shop_id = ci.shop_id
      AND p.partner_id = ci.partner_id
     JOIN app.product_variants AS v
       ON v.id = ci.variant_id
      AND v.product_id = ci.product_id
      AND v.shop_id = ci.shop_id
      AND v.partner_id = ci.partner_id
     JOIN app.shops AS s
       ON s.id = p.shop_id AND s.partner_id = p.partner_id
     JOIN app.partners AS partner ON partner.id = p.partner_id
     LEFT JOIN app.categories AS category
       ON category.id = p.category_id
      AND category.shop_id = p.shop_id
      AND category.partner_id = p.partner_id
     WHERE ci.cart_id = $1
     ORDER BY p.name, p.id, v.sort_order, v.id${lock ? ' FOR UPDATE OF p, s, partner, v' : ''}`,
    [cartId],
  );
  return result.rows;
}

function formatCart(cart, items) {
  let subtotal = 0n;
  let itemCount = 0;
  const formattedItems = items.map((item) => {
    const priceMinor = BigInt(item.price_minor);
    const lineTotalMinor = priceMinor * BigInt(item.quantity);
    subtotal += lineTotalMinor;
    itemCount += Number(item.quantity);
    return {
      productId: item.product_id,
      variantId: item.variant_id,
      variantLabel: item.variant_label,
      shopId: item.shop_id,
      name: item.name,
      sku: item.variant_sku,
      quantity: Number(item.quantity),
      priceMinor: priceMinor.toString(),
      lineTotalMinor: lineTotalMinor.toString(),
      currency: item.currency.trim(),
      available:
        item.product_status === 'active' &&
        item.product_is_available &&
        item.variant_is_available &&
        item.shop_status === 'active' &&
        item.partner_status === 'approved' &&
        (item.variant_stock === null ||
          Number(item.variant_stock) >= Number(item.quantity)),
    };
  });

  return {
    shopId: cart.shop_id,
    items: formattedItems,
    itemCount,
    itemSubtotalMinor: subtotal.toString(),
  };
}

async function loadCheckoutItems(client, cart, { lock = false } = {}) {
  const items = await readCartItems(client, cart.id, { lock });
  if (items.length === 0) {
    throw new ApiError(422, 'EMPTY_CART', 'Add at least one item before checkout.');
  }

  let subtotal = 0n;
  let currency = null;
  for (const item of items) {
    if (
      item.shop_id !== cart.shop_id ||
      item.partner_id !== cart.partner_id
    ) {
      throw new ApiError(
        409,
        'CART_SHOP_MISMATCH',
        'A cart can contain products from only one shop.',
      );
    }
    if (
      item.product_status !== 'active' ||
      !item.product_is_available ||
      !item.variant_is_available ||
      item.shop_status !== 'active' ||
      item.partner_status !== 'approved'
    ) {
      throw new ApiError(
        409,
        'CART_ITEM_UNAVAILABLE',
        'One or more cart items are currently unavailable.',
      );
    }
    assertStock({ stock: item.variant_stock }, Number(item.quantity));
    if (currency !== null && currency !== item.currency.trim()) {
      throw new ApiError(
        409,
        'MIXED_CURRENCIES',
        'Cart items must use the same currency.',
      );
    }
    currency = item.currency.trim();
    const lineTotal = BigInt(item.price_minor) * BigInt(item.quantity);
    if (lineTotal > MAX_BIGINT || subtotal + lineTotal > MAX_BIGINT) {
      throw new ApiError(422, 'ORDER_TOTAL_TOO_LARGE', 'Order total is too large.');
    }
    item.line_total_minor = lineTotal.toString();
    subtotal += lineTotal;
  }

  return { items, subtotal, currency };
}

function validateDeliveryAddress(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { error: 'deliveryAddress must be a JSON object.' };
  }
  if (Object.keys(value).length === 0) {
    return { error: 'deliveryAddress must not be empty.' };
  }
  const pincode = typeof value.pincode === 'string' ? value.pincode.trim() : '';
  if (!/^\d{6}$/.test(pincode)) {
    return {
      error: 'deliveryAddress.pincode must be a 6-digit string.',
    };
  }
  const latitude = value.latitude;
  const longitude = value.longitude;
  if (latitude === undefined || longitude === undefined) {
    return {
      error: 'deliveryAddress must include latitude and longitude.',
      code: 'ADDRESS_LOCATION_REQUIRED',
    };
  }
  let destination;
  try {
    destination = validateCoordinates({ latitude, longitude });
  } catch {
    return {
      error: 'deliveryAddress coordinates must be finite and within India.',
      code: 'ADDRESS_LOCATION_INVALID',
    };
  }

  let serialized;
  try {
    serialized = JSON.stringify({ ...omitClientPricingFields(value), pincode });
  } catch {
    return { error: 'deliveryAddress must be valid JSON.' };
  }
  if (!serialized || Buffer.byteLength(serialized, 'utf8') > 4096) {
    return { error: 'deliveryAddress must not exceed 4096 bytes.' };
  }
  return { value: serialized, pincode, destination };
}

function validateQuoteDeliveryAddress(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return { error: 'deliveryAddress must be a JSON object.' };
  }
  const formattedAddress =
    typeof value.formattedAddress === 'string' ? value.formattedAddress.trim() : '';
  if (!formattedAddress || formattedAddress.length > 300) {
    return {
      error: 'deliveryAddress.formattedAddress must be a non-empty string of at most 300 characters.',
    };
  }
  const validatedAddress = validateDeliveryAddress(value);
  if (validatedAddress.error) return validatedAddress;

  const destination = validatedAddress.destination;

  let serialized;
  try {
    serialized = JSON.stringify({
      ...omitClientPricingFields(value),
      formattedAddress,
      pincode: validatedAddress.pincode,
    });
  } catch {
    return { error: 'deliveryAddress must be valid JSON.' };
  }
  if (!serialized || Buffer.byteLength(serialized, 'utf8') > 4096) {
    return { error: 'deliveryAddress must not exceed 4096 bytes.' };
  }
  return { value: serialized, pincode: validatedAddress.pincode, destination };
}

function createCartCheckoutRouter({
  databasePool,
  authenticateCustomer = null,
  deliveryDistanceClient = null,
  razorpayClient = null,
  razorpayKeyId = null,
  razorpayKeySecret = null,
}) {
  const router = express.Router();
  const cartOwnershipRequired = requireCustomerCartOwnership(
    authenticateCustomer,
  );
  router.use(['/carts', '/cart'], cartOwnershipRequired);

  router.post('/carts', async (req, res, next) => {
    const body = parseObjectBody(req.body ?? {}, new Set());
    if (body.error) {
      return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
    }
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const cartToken = randomBytes(32).toString('base64url');
      const cartId = randomUUID();
      await databasePool.query(
        `INSERT INTO app.customer_carts (id, token_hash, customer_user_id)
         VALUES ($1, $2, $3)`,
        [cartId, hashCartToken(cartToken), req.auth.customerUserId],
      );
      return res.status(201).json({ data: { cartToken } });
    } catch (error) {
      return next(error);
    }
  });

  router.get('/cart', async (req, res, next) => {
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const tokenHash = hashCartToken(getCartToken(req));
      const cart = await withTransaction(databasePool, async (client) => {
        const currentCart = await findCart(
          client,
          tokenHash,
          req.auth.customerUserId,
          { lock: true },
        );
        const items = await readCartItems(client, currentCart.id);
        return formatCart(currentCart, items);
      });
      return res.status(200).json({ data: cart });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.post('/cart/items', async (req, res, next) => {
    const body = parseObjectBody(
      req.body,
      new Set(['productId', 'variantId', 'quantity']),
    );
    if (body.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
    const product = parseProductId(body.value.productId);
    if (product.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', product.error));
    const variant = parseVariantId(body.value.variantId);
    if (variant.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', variant.error));
    const quantity = parseQuantity(body.value.quantity, { optional: true });
    if (quantity.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', quantity.error));
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const tokenHash = hashCartToken(getCartToken(req));
      const cart = await withTransaction(databasePool, async (client) => {
        const currentCart = await findCart(
          client,
          tokenHash,
          req.auth.customerUserId,
          { lock: true },
        );
        const currentProduct = await findProduct(client, product.value);
        const currentVariant = await findVariant(
          client,
          currentProduct,
          variant.value,
        );
        if (
          currentCart.shop_id &&
          (currentCart.shop_id !== currentProduct.shop_id ||
            currentCart.partner_id !== currentProduct.partner_id)
        ) {
          throw new ApiError(
            409,
            'CART_SHOP_MISMATCH',
            'A cart can contain products from only one shop.',
          );
        }

        const existingResult = await client.query(
          `SELECT ci.quantity, p.currency
           FROM app.customer_cart_items AS ci
           JOIN app.products AS p ON p.id = ci.product_id
           WHERE ci.cart_id = $1
           ORDER BY ci.product_id
           FOR SHARE OF p`,
          [currentCart.id],
        );
        const existing = existingResult.rows.find(
          (item) => item.currency.trim() !== currentProduct.currency.trim(),
        );
        if (existing) {
          throw new ApiError(
            409,
            'MIXED_CURRENCIES',
            'Cart items must use the same currency.',
          );
        }

        const currentItemResult = await client.query(
          `SELECT quantity
           FROM app.customer_cart_items
           WHERE cart_id = $1 AND product_id = $2 AND variant_id = $3
           FOR UPDATE`,
          [currentCart.id, product.value, variant.value],
        );
        const totalQuantity =
          Number(currentItemResult.rows[0]?.quantity ?? 0) + quantity.value;
        if (totalQuantity > MAX_QUANTITY) {
          throw new ApiError(
            400,
            'INVALID_QUANTITY',
            `quantity must not exceed ${MAX_QUANTITY} for a variant.`,
          );
        }
        assertStock(currentVariant, totalQuantity);

        if (!currentCart.shop_id) {
          await client.query(
            `UPDATE app.customer_carts
             SET shop_id = $2, partner_id = $3, updated_at = now()
             WHERE id = $1`,
            [currentCart.id, currentProduct.shop_id, currentProduct.partner_id],
          );
        }
        const itemResult = await client.query(
          `INSERT INTO app.customer_cart_items
             (cart_id, product_id, variant_id, shop_id, partner_id, quantity)
           VALUES ($1, $2, $3, $4, $5, $6)
           ON CONFLICT (cart_id, product_id, variant_id)
           DO UPDATE SET quantity = EXCLUDED.quantity, updated_at = now()
           RETURNING quantity`,
          [
            currentCart.id,
            product.value,
            variant.value,
            currentProduct.shop_id,
            currentProduct.partner_id,
            totalQuantity,
          ],
        );
        return {
          productId: product.value,
          variantId: variant.value,
          quantity: Number(itemResult.rows[0].quantity),
        };
      });
      return res.status(200).json({ data: cart });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.patch('/cart/items/:productId/:variantId', async (req, res, next) => {
    const product = parseProductId(req.params.productId);
    if (product.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', product.error));
    const variant = parseVariantId(req.params.variantId);
    if (variant.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', variant.error));
    const body = parseObjectBody(req.body, new Set(['quantity']));
    if (body.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
    const quantity = parseQuantity(body.value.quantity);
    if (quantity.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', quantity.error));
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const tokenHash = hashCartToken(getCartToken(req));
      const item = await withTransaction(databasePool, async (client) => {
        const cart = await findCart(
          client,
          tokenHash,
          req.auth.customerUserId,
          { lock: true },
        );
        const productRecord = await findProduct(client, product.value);
        const variantRecord = await findVariant(
          client,
          productRecord,
          variant.value,
          { lock: true },
        );
        const existing = await client.query(
          `SELECT quantity
           FROM app.customer_cart_items
           WHERE cart_id = $1 AND product_id = $2 AND variant_id = $3
           FOR UPDATE`,
          [cart.id, product.value, variant.value],
        );
        if (existing.rows.length === 0) {
          throw new ApiError(404, 'CART_ITEM_NOT_FOUND', 'Cart item not found.');
        }
        assertStock(variantRecord, quantity.value);

        const result = await client.query(
          `UPDATE app.customer_cart_items
           SET quantity = $3, updated_at = now()
           WHERE cart_id = $1 AND product_id = $2 AND variant_id = $4
           RETURNING quantity`,
          [cart.id, product.value, quantity.value, variant.value],
        );
        return {
          productId: product.value,
          variantId: variant.value,
          quantity: Number(result.rows[0].quantity),
        };
      });
      return res.status(200).json({ data: item });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.delete('/cart/items/:productId/:variantId', async (req, res, next) => {
    const product = parseProductId(req.params.productId);
    if (product.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', product.error));
    const variant = parseVariantId(req.params.variantId);
    if (variant.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', variant.error));
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const tokenHash = hashCartToken(getCartToken(req));
      await withTransaction(databasePool, async (client) => {
        const cart = await findCart(
          client,
          tokenHash,
          req.auth.customerUserId,
          { lock: true },
        );
        const result = await client.query(
          `DELETE FROM app.customer_cart_items
           WHERE cart_id = $1 AND product_id = $2 AND variant_id = $3`,
          [cart.id, product.value, variant.value],
        );
        if (result.rowCount === 0) {
          throw new ApiError(404, 'CART_ITEM_NOT_FOUND', 'Cart item not found.');
        }

        const remaining = await client.query(
          `SELECT 1 FROM app.customer_cart_items WHERE cart_id = $1 LIMIT 1`,
          [cart.id],
        );
        if (remaining.rows.length === 0) {
          await client.query(
            `UPDATE app.customer_carts
             SET shop_id = NULL, partner_id = NULL, updated_at = now()
             WHERE id = $1`,
            [cart.id],
          );
        }
      });
      return res.status(204).end();
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.delete('/cart/items', async (req, res, next) => {
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const tokenHash = hashCartToken(getCartToken(req));
      const cart = await withTransaction(databasePool, async (client) => {
        const currentCart = await findCart(
          client,
          tokenHash,
          req.auth.customerUserId,
          { lock: true },
        );
        await client.query(
          `DELETE FROM app.customer_cart_items WHERE cart_id = $1`,
          [currentCart.id],
        );
        await client.query(
          `UPDATE app.customer_carts
           SET shop_id = NULL, partner_id = NULL, updated_at = now()
           WHERE id = $1`,
          [currentCart.id],
        );
        return { shopId: null, items: [], itemCount: 0, itemSubtotalMinor: '0' };
      });
      return res.status(200).json({ data: cart });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  router.post(
    '/checkout/quote',
    (req, res, next) => {
      if (!authenticateCustomer) {
        return res.status(401).json({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'Customer authentication is required to quote checkout.',
          },
        });
      }
      return invokeCustomerAuthentication(authenticateCustomer, req, res, next);
    },
    async (req, res, next) => {
      const body = parseObjectBody(
        req.body ?? {},
        new Set([
          'deliveryAddress',
          'deliveryFeeMinor',
          'distanceMeters',
          'deliveryDistanceM',
          'delivery_fee_minor',
          'delivery_distance_m',
          'distanceM',
          'distance_m',
        ]),
      );
      if (body.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
      const address = validateQuoteDeliveryAddress(body.value.deliveryAddress);
      if (address.error) {
        return sendApiError(
          res,
          new ApiError(
            address.code === 'ADDRESS_LOCATION_REQUIRED' ||
              address.code === 'ADDRESS_LOCATION_INVALID'
              ? 422
              : 400,
            address.code || 'INVALID_REQUEST',
            address.error,
          ),
        );
      }
      if (!databasePool) return sendDatabaseUnavailable(res);
      const customerUserId = req.auth?.customerUserId;
      if (typeof customerUserId !== 'string' || !UUID_PATTERN.test(customerUserId)) {
        return res.status(401).json({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'Customer authentication is required to quote checkout.',
          },
        });
      }

      try {
        const tokenHash = hashCartToken(getCartToken(req));
        const cartSnapshot = await withTransaction(databasePool, async (client) => {
          if (customerUserId) {
            await lockCustomer(client, customerUserId);
            const outstandingMinor = await getOutstandingMinor(client, customerUserId);
            if (outstandingMinor > 0n) {
              throw new ApiError(
                409,
                'OUTSTANDING_DUES',
                'Resolve outstanding delivery dues before placing another order.',
                { outstandingMinor: outstandingMinor.toString() },
              );
            }
          }
          const cart = await findCart(
            client,
            tokenHash,
            customerUserId,
            { lock: true },
          );
          const checkout = await loadCheckoutItems(client, cart);
          return {
            shopId: cart.shop_id,
            partnerId: cart.partner_id,
            ...checkout,
            storeHours: isOpenNow(checkout.items[0]),
          };
        });
        const quoteItems = cartSnapshot.items.map((item) => ({
          productId: item.product_id,
          variantId: item.variant_id,
          variantLabel: item.variant_label,
          name: item.name,
          quantity: Number(item.quantity),
          priceMinor: item.price_minor,
          lineTotalMinor: item.line_total_minor,
        }));
        const quoteBase = {
          items: quoteItems,
          currency: cartSnapshot.currency,
          storeOpen: cartSnapshot.storeHours.open,
          opensAt: cartSnapshot.storeHours.opensAt,
          closesAt: cartSnapshot.storeHours.closesAt,
          itemSubtotalMinor: cartSnapshot.subtotal.toString(),
          discountMinor: '0',
        };

        const pincodeResult = await databasePool.query(
          `SELECT EXISTS (
             SELECT 1
             FROM app.serviceable_pincodes
             WHERE pincode = $1
               AND is_active = true
           ) AS is_deliverable`,
          [address.pincode],
        );
        if (!pincodeResult.rows[0]?.is_deliverable) {
          return res.status(200).json({
            data: {
              ...quoteBase,
              isDeliverable: false,
              message: 'Sorry, we do not deliver to this location.',
              distanceMeters: null,
              deliveryFeeMinor: null,
              platformFeeMinor: null,
              totalMinor: null,
            },
          });
        }

        let origin;
        try {
          origin = validateCoordinates({
            latitude: cartSnapshot.items[0].shop_latitude,
            longitude: cartSnapshot.items[0].shop_longitude,
          });
        } catch {
          return sendApiError(
            res,
            new ApiError(
              503,
              'SHOP_LOCATION_UNAVAILABLE',
              'The shop delivery location could not be verified.',
            ),
          );
        }
        if (!deliveryDistanceClient) {
          return sendApiError(
            res,
            new ApiError(
              503,
              'DISTANCE_UNAVAILABLE',
              'Delivery distance could not be verified.',
            ),
          );
        }

        let distanceMeters;
        try {
          distanceMeters = await deliveryDistanceClient.getRoadDistanceMetres(
            origin,
            address.destination,
          );
        } catch {
          return sendApiError(
            res,
            new ApiError(
              503,
              'DISTANCE_UNAVAILABLE',
              'Delivery distance could not be verified.',
            ),
          );
        }
        if (!Number.isSafeInteger(distanceMeters) || distanceMeters < 0) {
          return sendApiError(
            res,
            new ApiError(
              503,
              'DISTANCE_UNAVAILABLE',
              'Delivery distance could not be verified.',
            ),
          );
        }

        if (cartSnapshot.subtotal > BigInt(Number.MAX_SAFE_INTEGER)) {
          throw new ApiError(
            422,
            'ORDER_TOTAL_TOO_LARGE',
            'Order total is too large.',
          );
        }
        let deliveryFeeMinor;
        try {
          deliveryFeeMinor = computeDeliveryFeeMinor('standard', distanceMeters);
        } catch {
          return sendApiError(
            res,
            new ApiError(
              503,
              'DISTANCE_UNAVAILABLE',
              'Delivery distance could not be verified.',
            ),
          );
        }
        const platformFeeMinor = PLATFORM_FEE_MINOR;
        const totalMinor =
          cartSnapshot.subtotal + BigInt(deliveryFeeMinor) + BigInt(platformFeeMinor);
        return res.status(200).json({
          data: {
            ...quoteBase,
            isDeliverable: true,
            message: 'Delivery is available at this location.',
            distanceMeters,
            deliveryFeeMinor: String(deliveryFeeMinor),
            platformFeeMinor: String(platformFeeMinor),
            totalMinor: totalMinor.toString(),
          },
        });
        } catch (error) {
          if (error instanceof ApiError) return sendApiError(res, error);
          return next(error);
        }
    },
  );

  router.post(
    '/orders',
    (req, res, next) => {
      if (!authenticateCustomer) {
        return res.status(401).json({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'Customer authentication is required to place an order.',
          },
        });
      }
      return invokeCustomerAuthentication(authenticateCustomer, req, res, next);
    },
    async (req, res, next) => {
      const body = parseObjectBody(
        req.body,
        new Set([
          'deliveryAddress',
          'paymentMethod',
          'checkoutRequestId',
          'deliveryFeeMinor',
          'distanceMeters',
          'deliveryDistanceM',
          'delivery_fee_minor',
          'delivery_distance_m',
          'distanceM',
          'distance_m',
        ]),
      );
      if (body.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
      const paymentMethod = body.value.paymentMethod ?? 'cod';
      if (!['cod', 'prepaid'].includes(paymentMethod)) {
        return sendApiError(
          res,
          new ApiError(400, 'INVALID_REQUEST', 'paymentMethod must be cod or prepaid.'),
        );
      }
      const checkoutRequestId = body.value.checkoutRequestId;
      if (
        paymentMethod === 'prepaid' &&
        (typeof checkoutRequestId !== 'string' ||
          !UUID_PATTERN.test(checkoutRequestId))
      ) {
        return sendApiError(
          res,
          new ApiError(
            400,
            'INVALID_REQUEST',
            'checkoutRequestId must be a valid UUID for prepaid checkout.',
          ),
        );
      }
      if (paymentMethod === 'prepaid' && (!razorpayClient || !razorpayKeyId)) {
        return sendApiError(
          res,
          new ApiError(
            503,
            'PAYMENT_UNAVAILABLE',
            'Online payment is temporarily unavailable.',
          ),
        );
      }
      const address = validateDeliveryAddress(body.value.deliveryAddress);
      if (address.error) {
        return sendApiError(
          res,
          new ApiError(
            address.code === 'ADDRESS_LOCATION_REQUIRED' ||
              address.code === 'ADDRESS_LOCATION_INVALID'
              ? 422
              : 400,
            address.code || 'INVALID_REQUEST',
            address.error,
          ),
        );
      }

      const customerUserId = req.auth?.customerUserId;
      if (typeof customerUserId !== 'string' || !UUID_PATTERN.test(customerUserId)) {
        return res.status(401).json({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'Customer authentication is required to place an order.',
          },
        });
      }
      if (!databasePool) return sendDatabaseUnavailable(res);

      try {
        const tokenHash = hashCartToken(getCartToken(req));
        const order = await withTransaction(databasePool, async (client) => {
          if (customerUserId) {
            await lockCustomer(client, customerUserId);
            if (paymentMethod === 'prepaid') {
              const existingPayment = await client.query(
                `SELECT
                   payment.id AS payment_attempt_id,
                   payment.provider_order_id,
                   payment.status AS payment_status,
                   payment.amount_minor::text AS total_minor,
                   payment.currency,
                   orders.id AS order_id,
                   orders.status AS order_status,
                   orders.items_subtotal_minor::text AS items_subtotal_minor,
                   orders.delivery_fee_minor::text AS delivery_fee_minor,
                   orders.discount_minor::text AS discount_minor
                 FROM app.order_payment_attempts AS payment
                 JOIN app.orders AS orders ON orders.id = payment.order_id
                 WHERE payment.customer_user_id = $1
                   AND payment.checkout_request_id = $2
                 FOR UPDATE OF payment, orders`,
                [customerUserId, checkoutRequestId],
              );
              if (existingPayment.rows.length > 0) {
                const payment = existingPayment.rows[0];
                const itemCount = await client.query(
                  `SELECT count(*)::integer AS count
                   FROM app.order_items
                   WHERE order_id = $1`,
                  [payment.order_id],
                );
                return {
                  ...formatPaymentOrderResult(
                    payment,
                    Number(itemCount.rows[0].count),
                  ),
                  paymentAttempt: payment,
                  isExisting: true,
                };
              }
            }
            const outstandingMinor = await getOutstandingMinor(client, customerUserId);
            if (outstandingMinor > 0n) {
              throw new ApiError(
                409,
                'OUTSTANDING_DUES',
                'Resolve outstanding delivery dues before placing another order.',
                { outstandingMinor: outstandingMinor.toString() },
              );
            }
          }
          const deliveryZone = await client.query(
            `SELECT 1
             FROM app.serviceable_pincodes
             WHERE pincode = $1
               AND is_active = true`,
            [address.pincode],
          );
          if (deliveryZone.rows.length === 0) {
            throw new ApiError(
              422,
              'DELIVERY_UNAVAILABLE',
              'Sorry, we do not deliver to this location.',
            );
          }

          if (customerUserId) {
            const customer = await client.query(
              `SELECT c.user_id
               FROM app.customers AS c
               JOIN app.users AS u ON u.id = c.user_id
               WHERE c.user_id = $1
                 AND u.system_role = 'customer'
                 AND u.status = 'active'
               FOR SHARE OF c, u`,
              [customerUserId],
            );
            if (customer.rows.length === 0) {
              throw new ApiError(
                403,
                'CUSTOMER_NOT_ALLOWED',
                'The authenticated account cannot place customer orders.',
              );
            }
          }

          const cart = await findCart(
            client,
            tokenHash,
            customerUserId,
            { lock: true },
          );
          if (!cart.shop_id || !cart.partner_id) {
            throw new ApiError(422, 'EMPTY_CART', 'Add at least one item before checkout.');
          }
          const checkout = await loadCheckoutItems(client, cart, { lock: true });
          const operatingHours = isOpenNow(checkout.items[0]);
          if (!operatingHours.open) {
            throw new ApiError(
              409,
              'STORE_CLOSED',
              formatHoursMessage(operatingHours),
            );
          }
          const orderId = randomUUID();
          let shopCoordinates;
          try {
            shopCoordinates = validateCoordinates({
              latitude: checkout.items[0].shop_latitude,
              longitude: checkout.items[0].shop_longitude,
            });
          } catch {
            throw new ApiError(
              503,
              'SHOP_LOCATION_UNAVAILABLE',
              'The shop delivery location could not be verified.',
            );
          }
          if (!deliveryDistanceClient) {
            throw new ApiError(
              503,
              'DISTANCE_UNAVAILABLE',
              'Delivery distance could not be verified.',
            );
          }
          let deliveryDistanceM;
          try {
            deliveryDistanceM =
              await deliveryDistanceClient.getRoadDistanceMetres(
                shopCoordinates,
                address.destination,
              );
          } catch {
            throw new ApiError(
              503,
              'DISTANCE_UNAVAILABLE',
              'Delivery distance could not be verified.',
            );
          }
          if (!Number.isSafeInteger(deliveryDistanceM) || deliveryDistanceM < 0) {
            throw new ApiError(
              503,
              'DISTANCE_UNAVAILABLE',
              'Delivery distance could not be verified.',
            );
          }
          let deliveryFeeMinor;
          try {
            deliveryFeeMinor = computeDeliveryFeeMinor(
              'standard',
              deliveryDistanceM,
            );
          } catch {
            throw new ApiError(
              503,
              'DISTANCE_UNAVAILABLE',
              'Delivery distance could not be verified.',
            );
          }
          const deliveryFee = BigInt(deliveryFeeMinor);
          const platformFee = BigInt(PLATFORM_FEE_MINOR);
          const discount = 0n;
          const total =
            checkout.subtotal + deliveryFee + platformFee - discount;
          if (total > BigInt(Number.MAX_SAFE_INTEGER)) {
            throw new ApiError(
              422,
              'ORDER_TOTAL_TOO_LARGE',
              'Order total is too large.',
            );
          }
          let commissionTotalMinor = 0n;
          for (const item of checkout.items) {
            item.commission_bps = resolveCommissionBps({
              categoryOverride: item.category_commission_bps_override,
              partnerOverride: item.partner_commission_bps_override,
              categoryCode: item.category_code,
              partnerType: item.partner_type,
            });
            item.commission_minor = computeCommissionMinor(
              item.line_total_minor,
              item.commission_bps,
            );
            commissionTotalMinor += item.commission_minor;
          }

          await client.query(
            `INSERT INTO app.orders (
               id, customer_user_id, partner_id, shop_id, status, currency,
               items_subtotal_minor, delivery_fee_minor, discount_minor,
               total_minor, delivery_address_snapshot, commission_minor,
               delivery_distance_m, delivery_fee_kind, platform_fee_minor,
               payment_method
             )
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12, $13, 'standard', $14, $15)`,
            [
              orderId,
              customerUserId,
              cart.partner_id,
              cart.shop_id,
              paymentMethod === 'prepaid' ? 'payment_pending' : 'placed',
              checkout.currency,
              checkout.subtotal.toString(),
              deliveryFee.toString(),
              discount.toString(),
              total.toString(),
              address.value,
              commissionTotalMinor.toString(),
              deliveryDistanceM,
              platformFee.toString(),
              paymentMethod,
            ],
          );

          for (const item of checkout.items) {
            if (item.variant_stock !== null) {
              const stock = await client.query(
                `UPDATE app.product_variants
                 SET stock = stock - $2,
                     updated_at = now()
                 WHERE id = $1
                   AND stock >= $2
                 RETURNING id`,
                [item.variant_id, Number(item.quantity)],
              );
              if (stock.rows.length === 0) {
                throw new ApiError(
                  409,
                  'INSUFFICIENT_STOCK',
                  'The requested quantity is no longer available.',
                );
              }
            }

            await client.query(
              `INSERT INTO app.order_items (
                 id, order_id, partner_id, shop_id, product_id,
                 product_name_snapshot, sku_snapshot, unit_price_minor,
                 quantity, line_total_minor, commission_bps, commission_minor,
                 currency, variant_snapshot
               )
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14::jsonb)`,
              [
                randomUUID(),
                orderId,
                item.partner_id,
                item.shop_id,
                item.product_id,
                item.name,
                item.variant_sku,
                item.price_minor,
                Number(item.quantity),
                item.line_total_minor,
                item.commission_bps,
                item.commission_minor.toString(),
                checkout.currency,
                JSON.stringify({
                  variantId: item.variant_id,
                  label: item.variant_label,
                  unit: item.variant_unit,
                  quantity: Number(item.variant_quantity),
                  sku: item.variant_sku,
                  unitPriceMinor: item.price_minor,
                }),
              ],
            );
          }

          await client.query(
            `DELETE FROM app.customer_cart_items WHERE cart_id = $1`,
            [cart.id],
          );
          await client.query(
            `UPDATE app.customer_carts
             SET shop_id = NULL, partner_id = NULL, updated_at = now()
             WHERE id = $1`,
            [cart.id],
          );

          const orderResult = {
            orderId,
            status: paymentMethod === 'prepaid' ? 'payment_pending' : 'placed',
            currency: checkout.currency,
            itemSubtotalMinor: checkout.subtotal.toString(),
            deliveryFeeMinor: deliveryFee.toString(),
            discountMinor: discount.toString(),
            totalMinor: total.toString(),
            items: checkout.items.length,
            paymentStatus: paymentMethod === 'prepaid' ? 'pending' : null,
            paymentVerified: false,
          };
          if (paymentMethod === 'prepaid') {
            const paymentAttemptId = randomUUID();
            await client.query(
              `INSERT INTO app.order_payment_attempts (
                 id, order_id, customer_user_id, checkout_request_id,
                 amount_minor, currency
               )
               VALUES ($1, $2, $3, $4, $5, $6)`,
              [
                paymentAttemptId,
                orderId,
                customerUserId,
                checkoutRequestId,
                total.toString(),
                checkout.currency,
              ],
            );
            orderResult.paymentAttempt = {
              payment_attempt_id: paymentAttemptId,
              provider_order_id: null,
              payment_status: 'pending',
              total_minor: total.toString(),
              currency: checkout.currency,
              order_id: orderId,
              order_status: 'payment_pending',
            };
            orderResult.isExisting = false;
          }
          return orderResult;
        });
        if (paymentMethod === 'prepaid') {
          if (order.paymentVerified) {
            const { paymentAttempt, isExisting, ...orderData } = order;
            return res.status(200).json({ data: orderData });
          }
          try {
            const checkout = await ensureRazorpayOrder({
              databasePool,
              razorpayClient,
              razorpayKeyId,
              paymentAttempt: order.paymentAttempt,
            });
            const {
              paymentAttempt,
              isExisting,
              ...orderData
            } = order;
            return res.status(isExisting ? 200 : 201).json({
              data: { ...orderData, checkout },
            });
          } catch (error) {
            if (error instanceof ApiError) return sendApiError(res, error);
            return sendApiError(
              res,
              new ApiError(
                502,
                'PAYMENT_PROVIDER_UNAVAILABLE',
                'Online payment could not be initialized. Retry checkout.',
              ),
            );
          }
        }
        return res.status(201).json({ data: order });
      } catch (error) {
        if (error instanceof ApiError) return sendApiError(res, error);
        return next(error);
      }
    },
  );

  router.post(
    '/orders/:orderId/verify-payment',
    (req, res, next) => {
      if (!authenticateCustomer) {
        return res.status(401).json({
          error: {
            code: 'AUTHENTICATION_REQUIRED',
            message: 'Customer authentication is required.',
          },
        });
      }
      return invokeCustomerAuthentication(
        authenticateCustomer,
        req,
        res,
        () => {
          const customerUserId = req.auth?.customerUserId;
          if (
            typeof customerUserId !== 'string' ||
            !UUID_PATTERN.test(customerUserId)
          ) {
            return res.status(401).json({
              error: {
                code: 'AUTHENTICATION_REQUIRED',
                message: 'Customer authentication is required.',
              },
            });
          }
          return next();
        },
      );
    },
    async (req, res, next) => {
      const orderId = req.params.orderId;
      if (typeof orderId !== 'string' || !UUID_PATTERN.test(orderId)) {
        return sendApiError(
          res,
          new ApiError(400, 'INVALID_REQUEST', 'orderId must be a valid UUID.'),
        );
      }
      const body = parseObjectBody(
        req.body,
        new Set(['razorpayOrderId', 'razorpayPaymentId', 'razorpaySignature']),
      );
      if (body.error) {
        return sendApiError(
          res,
          new ApiError(400, 'INVALID_REQUEST', body.error),
        );
      }
      const { razorpayOrderId, razorpayPaymentId, razorpaySignature } =
        body.value;
      if (
        typeof razorpayOrderId !== 'string' ||
        typeof razorpayPaymentId !== 'string' ||
        typeof razorpaySignature !== 'string'
      ) {
        return sendApiError(
          res,
          new ApiError(
            400,
            'INVALID_REQUEST',
            'Razorpay order, payment, and signature fields are required.',
          ),
        );
      }
      if (!databasePool) return sendDatabaseUnavailable(res);
      if (!razorpayClient || !razorpayKeySecret) {
        return sendApiError(
          res,
          new ApiError(
            503,
            'PAYMENT_UNAVAILABLE',
            'Online payment verification is temporarily unavailable.',
          ),
        );
      }

      try {
      const customerUserId = req.auth.customerUserId;
      const lookup = await databasePool.query(
        `SELECT
           payment.id AS payment_attempt_id,
           payment.provider_order_id,
           payment.provider_payment_id,
           payment.amount_minor::text AS total_minor,
           payment.currency,
           payment.status AS payment_status,
           orders.id AS order_id,
           orders.status AS order_status,
           orders.items_subtotal_minor::text AS items_subtotal_minor,
           orders.delivery_fee_minor::text AS delivery_fee_minor,
           orders.discount_minor::text AS discount_minor
         FROM app.order_payment_attempts AS payment
         JOIN app.orders AS orders ON orders.id = payment.order_id
         WHERE payment.order_id = $1
           AND payment.customer_user_id = $2`,
        [orderId, customerUserId],
      );
      if (lookup.rows.length === 0) {
        return sendApiError(
          res,
          new ApiError(404, 'ORDER_NOT_FOUND', 'Order not found.'),
        );
      }
      const payment = lookup.rows[0];
      if (
        payment.provider_order_id !== razorpayOrderId ||
        !verifyRazorpaySignature({
          orderId: payment.provider_order_id,
          paymentId: razorpayPaymentId,
          signature: razorpaySignature,
          keySecret: razorpayKeySecret,
        })
      ) {
        return sendApiError(
          res,
          new ApiError(
            400,
            'PAYMENT_VERIFICATION_FAILED',
            'Payment verification failed.',
          ),
        );
      }
      if (payment.payment_status === 'verified') {
        if (payment.provider_payment_id !== razorpayPaymentId) {
          return sendApiError(
            res,
            new ApiError(
              409,
              'PAYMENT_ALREADY_VERIFIED',
              'A different payment has already verified this order.',
            ),
          );
        }
        const itemCount = await databasePool.query(
          `SELECT count(*)::integer AS count
           FROM app.order_items
           WHERE order_id = $1`,
          [orderId],
        );
        return res.status(200).json({
          data: formatPaymentOrderResult(
            payment,
            Number(itemCount.rows[0].count),
          ),
          },
        );
      }

      let providerPayment;
      try {
        providerPayment = await razorpayClient.payments.fetch(
          razorpayPaymentId,
        );
      } catch {
        return sendApiError(
          res,
          new ApiError(
            502,
            'PAYMENT_PROVIDER_UNAVAILABLE',
            'Payment verification could not be completed. Retry verification.',
          ),
        );
      }
      if (
        providerPayment.order_id !== payment.provider_order_id ||
        Number(providerPayment.amount) !== Number(payment.total_minor) ||
        providerPayment.currency !== payment.currency.trim() ||
        providerPayment.status !== 'captured'
      ) {
        return sendApiError(
          res,
          new ApiError(
            409,
            'PAYMENT_NOT_CAPTURED',
            'The payment has not been captured by the provider.',
          ),
        );
      }

      const verifiedOrder = await withTransaction(databasePool, async (client) => {
        const current = await client.query(
          `SELECT
             payment.id AS payment_attempt_id,
             payment.provider_order_id,
             payment.provider_payment_id,
             payment.amount_minor::text AS total_minor,
             payment.currency,
             payment.status AS payment_status,
             orders.id AS order_id,
             orders.status AS order_status,
             orders.items_subtotal_minor::text AS items_subtotal_minor,
             orders.delivery_fee_minor::text AS delivery_fee_minor,
             orders.discount_minor::text AS discount_minor
           FROM app.order_payment_attempts AS payment
           JOIN app.orders AS orders ON orders.id = payment.order_id
           WHERE payment.order_id = $1
             AND payment.customer_user_id = $2
           FOR UPDATE OF payment, orders`,
          [orderId, customerUserId],
        );
        if (current.rows.length === 0) {
          throw new ApiError(404, 'ORDER_NOT_FOUND', 'Order not found.');
        }
        const currentPayment = current.rows[0];
        if (currentPayment.payment_status === 'verified') {
          if (currentPayment.provider_payment_id !== razorpayPaymentId) {
            throw new ApiError(
              409,
              'PAYMENT_ALREADY_VERIFIED',
              'A different payment has already verified this order.',
            );
          }
        } else {
          await client.query(
            `UPDATE app.order_payment_attempts
             SET status = 'verified',
                 provider_payment_id = $2,
                 verified_at = now()
             WHERE id = $1 AND status = 'pending'`,
            [currentPayment.payment_attempt_id, razorpayPaymentId],
          );
          const updatedOrder = await client.query(
            `UPDATE app.orders
             SET status = 'placed', updated_at = now()
             WHERE id = $1 AND status = 'payment_pending'
             RETURNING id`,
            [orderId],
          );
          if (updatedOrder.rows.length === 0) {
            throw new ApiError(
              409,
              'ORDER_STATE_CONFLICT',
              'The order is no longer awaiting payment.',
            );
          }
        }
        const itemCount = await client.query(
          `SELECT count(*)::integer AS count
           FROM app.order_items
           WHERE order_id = $1`,
          [orderId],
        );
        return formatPaymentOrderResult(
          {
            ...currentPayment,
            order_status: 'placed',
            payment_status: 'verified',
          },
          Number(itemCount.rows[0].count),
        );
      });
      return res.status(200).json({ data: verifiedOrder });
    } catch (error) {
      if (error instanceof ApiError) return sendApiError(res, error);
      return next(error);
    }
  });

  return router;
}

module.exports = { createCartCheckoutRouter };
