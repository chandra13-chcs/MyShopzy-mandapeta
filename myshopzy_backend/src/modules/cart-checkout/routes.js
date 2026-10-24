const { createHash, randomBytes, randomUUID } = require('node:crypto');
const express = require('express');
const { isOpenNow } = require('../shared/store-hours');
const {
  computeCommissionMinor,
  resolveCommissionBps,
} = require('../commission/rules');
const { getOutstandingMinor, lockCustomer } = require('../dues/ledger');

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CART_TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;
const MAX_QUANTITY = 99;
const MAX_BIGINT = 9223372036854775807n;

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

async function findCart(client, tokenHash, { lock = false } = {}) {
  const result = await client.query(
    `SELECT id, shop_id, partner_id
     FROM app.customer_carts
     WHERE token_hash = $1${lock ? ' FOR UPDATE' : ''}`,
    [tokenHash],
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

  let serialized;
  try {
    serialized = JSON.stringify({ ...value, pincode });
  } catch {
    return { error: 'deliveryAddress must be valid JSON.' };
  }
  if (!serialized || Buffer.byteLength(serialized, 'utf8') > 4096) {
    return { error: 'deliveryAddress must not exceed 4096 bytes.' };
  }
  return { value: serialized, pincode };
}

function createCartCheckoutRouter({
  databasePool,
  authenticateCustomer = null,
}) {
  const router = express.Router();

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
        `INSERT INTO app.customer_carts (id, token_hash)
         VALUES ($1, $2)`,
        [cartId, hashCartToken(cartToken)],
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
        const currentCart = await findCart(client, tokenHash, { lock: true });
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
        const currentCart = await findCart(client, tokenHash, { lock: true });
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
        const cart = await findCart(client, tokenHash, { lock: true });
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
        const cart = await findCart(client, tokenHash, { lock: true });
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
        const currentCart = await findCart(client, tokenHash, { lock: true });
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
      const body = parseObjectBody(req.body ?? {}, new Set());
      if (body.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
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
        const quote = await withTransaction(databasePool, async (client) => {
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
          const cart = await findCart(client, tokenHash, { lock: true });
          const checkout = await loadCheckoutItems(client, cart);
          return {
            ...checkout,
            storeHours: isOpenNow(checkout.items[0]),
          };
        });
        return res.status(200).json({
          data: {
            items: quote.items.map((item) => ({
              productId: item.product_id,
              variantId: item.variant_id,
              variantLabel: item.variant_label,
              name: item.name,
              quantity: Number(item.quantity),
              priceMinor: item.price_minor,
              lineTotalMinor: item.line_total_minor,
            })),
            currency: quote.currency,
            storeOpen: quote.storeHours.open,
            opensAt: quote.storeHours.opensAt,
            closesAt: quote.storeHours.closesAt,
            itemSubtotalMinor: quote.subtotal.toString(),
            deliveryFeeMinor: '0',
            discountMinor: '0',
            totalMinor: quote.subtotal.toString(),
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
      const body = parseObjectBody(req.body, new Set(['deliveryAddress']));
      if (body.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', body.error));
      const address = validateDeliveryAddress(body.value.deliveryAddress);
      if (address.error) return sendApiError(res, new ApiError(400, 'INVALID_REQUEST', address.error));

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

          const cart = await findCart(client, tokenHash, { lock: true });
          if (!cart.shop_id || !cart.partner_id) {
            throw new ApiError(422, 'EMPTY_CART', 'Add at least one item before checkout.');
          }
          const checkout = await loadCheckoutItems(client, cart, { lock: true });
          if (!isOpenNow(checkout.items[0]).open) {
            throw new ApiError(
              409,
              'STORE_CLOSED',
              'Orders are accepted between 7:00 AM and 11:00 PM',
            );
          }
          const orderId = randomUUID();
          const deliveryFee = 0n;
          const discount = 0n;
          const total = checkout.subtotal + deliveryFee - discount;
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
               payment_method
             )
             VALUES ($1, $2, $3, $4, 'placed', $5, $6, $7, $8, $9, $10::jsonb, $11, 'cod')`,
            [
              orderId,
              customerUserId,
              cart.partner_id,
              cart.shop_id,
              checkout.currency,
              checkout.subtotal.toString(),
              deliveryFee.toString(),
              discount.toString(),
              total.toString(),
              address.value,
              commissionTotalMinor.toString(),
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

          return {
            orderId,
            status: 'placed',
            currency: checkout.currency,
            itemSubtotalMinor: checkout.subtotal.toString(),
            deliveryFeeMinor: deliveryFee.toString(),
            discountMinor: discount.toString(),
            totalMinor: total.toString(),
            items: checkout.items.length,
          };
        });
        return res.status(201).json({ data: order });
      } catch (error) {
        if (error instanceof ApiError) return sendApiError(res, error);
        return next(error);
      }
    },
  );

  return router;
}

module.exports = { createCartCheckoutRouter };
