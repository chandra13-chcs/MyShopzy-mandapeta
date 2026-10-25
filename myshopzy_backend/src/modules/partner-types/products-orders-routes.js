const { randomUUID } = require('node:crypto');
const express = require('express');
const {
  VARIANT_LIMITS,
  validateProductName,
  validateVariantWithAllowedUnits,
} = require('../shared/variant-rules');
const { isOpenNow } = require('../shared/store-hours');
const { getPartnerTypeProfile } = require('./profiles');

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ORDER_STATUSES = Object.freeze([
  'placed',
  'confirmed',
  'preparing',
  'packed',
  'ready_for_pickup',
  'picked_up',
  'out_for_delivery',
  'delivered',
  'cancelled',
  'rejected',
]);
const ORDER_TRANSITIONS = Object.freeze({
  placed: Object.freeze(['accepted', 'rejected']),
  accepted: Object.freeze(['preparing']),
  preparing: Object.freeze(['ready']),
  ready: Object.freeze([]),
});
const ORDER_STATUS_TO_DATABASE = Object.freeze({
  accepted: 'confirmed',
  ready: 'ready_for_pickup',
});

class PartnerApiError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function sendError(res, req, error) {
  return res.status(error.status).json({
    error: {
      code: error.code,
      message: error.message,
      ...(error.details ? { details: error.details } : {}),
    },
    meta: { requestId: req.requestId },
  });
}

function validateUuid(value, name) {
  if (typeof value !== 'string' || !UUID_PATTERN.test(value)) {
    throw new PartnerApiError(400, 'INVALID_REQUEST', `${name} must be a valid UUID.`);
  }
  return value;
}

function parsePage(query) {
  const limit = query.limit === undefined ? 25 : Number(query.limit);
  const offset = query.offset === undefined ? 0 : Number(query.offset);
  if (
    !Number.isInteger(limit) ||
    limit < 1 ||
    limit > 100 ||
    !Number.isSafeInteger(offset) ||
    offset < 0
  ) {
    throw new PartnerApiError(
      400,
      'INVALID_REQUEST',
      'limit must be 1-100 and offset must be a non-negative integer.',
    );
  }
  return { limit, offset };
}

function validateAttributes(attributes, profile) {
  if (
    attributes === undefined
  ) {
    const required = profile.extraProductFields
      .filter((field) => field.required)
      .map((field) => field.key);
    if (required.length > 0) {
      throw new PartnerApiError(
        400,
        'INVALID_PRODUCT_ATTRIBUTES',
        'Required product attributes are missing.',
        { fields: required },
      );
    }
    return {};
  }
  if (!attributes || typeof attributes !== 'object' || Array.isArray(attributes)) {
    throw new PartnerApiError(
      400,
      'INVALID_PRODUCT_ATTRIBUTES',
      'attributes must be a JSON object.',
    );
  }

  const definitions = new Map(
    profile.extraProductFields.map((field) => [field.key, field]),
  );
  const errors = [];
  for (const [key, value] of Object.entries(attributes)) {
    const field = definitions.get(key);
    if (!field) {
      errors.push(`Unknown attribute: ${key}.`);
      continue;
    }
    if (field.type === 'text' && typeof value !== 'string') {
      errors.push(`${key} must be text.`);
    } else if (field.type === 'boolean' && typeof value !== 'boolean') {
      errors.push(`${key} must be boolean.`);
    } else if (
      field.type === 'number' &&
      (typeof value !== 'number' || !Number.isFinite(value))
    ) {
      errors.push(`${key} must be a finite number.`);
    } else if (
      field.type === 'select' &&
      (typeof value !== 'string' || !field.options.includes(value))
    ) {
      errors.push(`${key} must be one of: ${field.options.join(', ')}.`);
    }
  }
  for (const field of profile.extraProductFields) {
    if (field.required && !Object.hasOwn(attributes, field.key)) {
      errors.push(`${field.key} is required.`);
    }
  }
  if (errors.length > 0) {
    throw new PartnerApiError(
      400,
      'INVALID_PRODUCT_ATTRIBUTES',
      'Product attributes do not match this partner type.',
      { fields: errors },
    );
  }
  return attributes;
}

function validateVariants(variants, profile) {
  if (!Array.isArray(variants) || variants.length === 0) {
    throw new PartnerApiError(
      400,
      'INVALID_VARIANTS',
      'variants must be a non-empty array.',
    );
  }
  if (variants.length > VARIANT_LIMITS.maxVariantsPerProduct) {
    throw new PartnerApiError(
      400,
      'INVALID_VARIANTS',
      `A product may have at most ${VARIANT_LIMITS.maxVariantsPerProduct} variants.`,
    );
  }
  const errors = [];
  const labels = new Set();
  const normalized = variants.map((variant, index) => {
    const result = validateVariantWithAllowedUnits(variant, profile.allowedUnits);
    errors.push(...result.errors.map((error) => `Variant ${index + 1}: ${error}`));
    if (result.normalizedUnit) {
      variant = { ...variant, unit: result.normalizedUnit };
    }
    if (typeof variant?.label === 'string') {
      const normalizedLabel = variant.label.trim().toLowerCase();
      if (labels.has(normalizedLabel)) {
        errors.push(`Variant ${index + 1}: label must be unique.`);
      }
      labels.add(normalizedLabel);
    }
    return variant;
  });
  if (errors.length > 0) {
    throw new PartnerApiError(400, 'INVALID_VARIANTS', 'One or more variants are invalid.', {
      fields: errors,
    });
  }
  return normalized;
}

function validateProductInput(body, profile, existing = null) {
  const merged = {
    name: body.name === undefined ? existing?.name : body.name,
    categoryId: body.categoryId === undefined ? existing?.category_id : body.categoryId,
    description: body.description === undefined ? existing?.description ?? null : body.description,
    attributes: body.attributes === undefined ? existing?.attributes : body.attributes,
    imageUrl: body.imageUrl === undefined ? existing?.image_url ?? null : body.imageUrl,
    variants: body.variants === undefined ? existing?.variants : body.variants,
    shopId: body.shopId === undefined ? existing?.shop_id : body.shopId,
  };

  const nameResult = validateProductName(merged.name);
  if (!nameResult.valid) {
    throw new PartnerApiError(400, 'INVALID_PRODUCT', nameResult.errors.join(' '));
  }
  if (merged.categoryId !== null) validateUuid(merged.categoryId, 'categoryId');
  if (typeof merged.description !== 'string' && merged.description !== null) {
    throw new PartnerApiError(400, 'INVALID_PRODUCT', 'description must be text or null.');
  }
  if (
    merged.imageUrl !== null &&
    (typeof merged.imageUrl !== 'string' || merged.imageUrl.length > 2048)
  ) {
    throw new PartnerApiError(400, 'INVALID_PRODUCT', 'imageUrl must be text up to 2048 characters or null.');
  }
  if (merged.shopId !== undefined && merged.shopId !== null) {
    validateUuid(merged.shopId, 'shopId');
  }
  return {
    name: merged.name.trim(),
    categoryId: merged.categoryId ?? null,
    description: merged.description?.trim() || null,
    attributes: validateAttributes(merged.attributes, profile),
    imageUrl: merged.imageUrl || null,
    variants: validateVariants(merged.variants, profile),
    shopId: merged.shopId,
  };
}

function summarizeVariants(variants) {
  const prices = variants.map((variant) => variant.price_minor);
  const allStockKnown = variants.every((variant) => variant.stock !== null);
  const inventoryQuantity = allStockKnown
    ? variants.reduce((sum, variant) => sum + variant.stock, 0)
    : null;
  if (inventoryQuantity !== null && inventoryQuantity > 2147483647) {
    throw new PartnerApiError(
      400,
      'INVALID_VARIANTS',
      'Combined variant stock exceeds the supported inventory quantity.',
    );
  }
  return {
    priceMinor: Math.min(...prices),
    inventoryQuantity,
    available: variants.some((variant) => variant.is_available),
  };
}

async function withTransaction(databasePool, callback) {
  const client = await databasePool.connect();
  let begun = false;
  try {
    await client.query('BEGIN');
    begun = true;
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    if (begun) await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function resolveShopId(client, context, requestedShopId) {
  const permittedShopIds = Array.isArray(context.shopIds) ? context.shopIds : [];
  const shopId = requestedShopId || (
    permittedShopIds.length === 1 ? permittedShopIds[0] : null
  );
  if (!shopId) {
    throw new PartnerApiError(
      400,
      'SHOP_SELECTION_REQUIRED',
      'shopId is required when the partner has more than one shop.',
    );
  }
  validateUuid(shopId, 'shopId');
  const result = await client.query(
    `SELECT id
     FROM app.shops
     WHERE id = $1::uuid AND partner_id = $2::uuid
     LIMIT 1`,
    [shopId, context.partnerId],
  );
  if (result.rows.length !== 1 || !permittedShopIds.includes(shopId)) {
    throw new PartnerApiError(404, 'SHOP_NOT_FOUND', 'Shop not found.');
  }
  return shopId;
}

async function verifyCategory(client, categoryId, shopId, partnerId) {
  if (categoryId === null) return;
  const result = await client.query(
    `SELECT id
     FROM app.categories
     WHERE id = $1::uuid
       AND shop_id = $2::uuid
       AND partner_id = $3::uuid
       AND is_active = true
     LIMIT 1`,
    [categoryId, shopId, partnerId],
  );
  if (result.rows.length !== 1) {
    throw new PartnerApiError(404, 'CATEGORY_NOT_FOUND', 'Category not found for this shop.');
  }
}

function variantValues(variant, product, index) {
  return [
    randomUUID(),
    product.id,
    product.partner_id,
    product.shop_id,
    variant.label.trim(),
    variant.unit,
    variant.quantity,
    variant.price_minor,
    variant.stock,
    variant.sku ?? null,
    variant.is_available,
    variant.sort_order ?? index,
  ];
}

async function insertVariants(client, variants, product) {
  for (const [index, variant] of variants.entries()) {
    await client.query(
      `INSERT INTO app.product_variants (
         id, product_id, partner_id, shop_id, label, unit, quantity,
         price_minor, stock, sku, is_available, sort_order
       )
       VALUES ($1::uuid, $2::uuid, $3::uuid, $4::uuid, $5, $6, $7, $8, $9, $10, $11, $12)`,
      variantValues(variant, product, index),
    );
  }
}

const PRODUCT_SELECT = `
  SELECT
    pr.id,
    pr.partner_id,
    pr.shop_id,
    pr.category_id,
    pr.sku,
    pr.name,
    pr.description,
    pr.price_minor,
    pr.currency,
    pr.inventory_quantity,
    pr.is_available,
    pr.status,
    pr.attributes,
    pr.image_url,
    pr.thumb_url,
    COALESCE((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id', v.id,
          'label', v.label,
          'unit', v.unit,
          'quantity', v.quantity,
          'price_minor', v.price_minor::text,
          'stock', v.stock,
          'is_available', v.is_available,
          'sort_order', v.sort_order
        ) ORDER BY v.sort_order, v.id
      )
      FROM app.product_variants AS v
      WHERE v.product_id = pr.id
    ), '[]'::jsonb) AS variants,
    s.name AS shop_name,
    s.operating_details,
    p.timezone,
    p.name AS partner_name,
    p.partner_type
  FROM app.products AS pr
  JOIN app.shops AS s
    ON s.id = pr.shop_id AND s.partner_id = pr.partner_id
  JOIN app.partners AS p ON p.id = pr.partner_id
`;

function createPartnerProductOrderRouter({ databasePool }) {
  const router = express.Router();

  router.get('/partner/products', async (req, res, next) => {
    if (!databasePool) {
      return sendError(
        res,
        req,
        new PartnerApiError(503, 'DATABASE_UNAVAILABLE', 'Products are temporarily unavailable.'),
      );
    }
    try {
      const page = parsePage(req.query);
      const shopId = req.query.shopId === undefined
        ? null
        : validateUuid(req.query.shopId, 'shopId');
      if (shopId && !req.partnerContext.shopIds.includes(shopId)) {
        throw new PartnerApiError(404, 'SHOP_NOT_FOUND', 'Shop not found.');
      }
      const result = await databasePool.query(
        `${PRODUCT_SELECT}
         WHERE pr.partner_id = $1::uuid
           AND ($2::uuid IS NULL OR pr.shop_id = $2::uuid)
         ORDER BY pr.created_at DESC, pr.id
         LIMIT $3 OFFSET $4`,
        [req.partnerContext.partnerId, shopId, page.limit, page.offset],
      );
      return res.status(200).json({
        data: result.rows.map((product) => ({
          ...product,
          storeOpen: isOpenNow(product).open,
        })),
        pagination: page,
      });
    } catch (error) {
      return error instanceof PartnerApiError ? sendError(res, req, error) : next(error);
    }
  });

  router.post('/partner/products', async (req, res, next) => {
    if (!databasePool) {
      return sendError(
        res,
        req,
        new PartnerApiError(503, 'DATABASE_UNAVAILABLE', 'Products are temporarily unavailable.'),
      );
    }
    try {
      const profile = getPartnerTypeProfile(req.partnerContext.partnerType);
      if (!profile) throw new PartnerApiError(403, 'PARTNER_TYPE_UNSUPPORTED', 'Unsupported partner type.');
      const productInput = validateProductInput(req.body ?? {}, profile);
      const product = await withTransaction(databasePool, async (client) => {
        const shopId = await resolveShopId(client, req.partnerContext, productInput.shopId);
        await verifyCategory(
          client,
          productInput.categoryId,
          shopId,
          req.partnerContext.partnerId,
        );
        const summary = summarizeVariants(productInput.variants);
        const createdProduct = {
          id: randomUUID(),
          partner_id: req.partnerContext.partnerId,
          shop_id: shopId,
        };
        await client.query(
          `INSERT INTO app.products (
             id, partner_id, shop_id, category_id, name, description,
             price_minor, inventory_quantity, is_available, attributes, image_url
           )
           VALUES (
             $1::uuid, $2::uuid, $3::uuid, $4::uuid, $5, $6, $7, $8, $9, $10::jsonb, $11
           )`,
          [
            createdProduct.id,
            createdProduct.partner_id,
            createdProduct.shop_id,
            productInput.categoryId,
            productInput.name,
            productInput.description,
            summary.priceMinor,
            summary.inventoryQuantity,
            summary.available,
            JSON.stringify(productInput.attributes),
            productInput.imageUrl,
          ],
        );
        await insertVariants(client, productInput.variants, createdProduct);
        const response = await client.query(
          `${PRODUCT_SELECT} WHERE pr.id = $1::uuid AND pr.partner_id = $2::uuid`,
          [createdProduct.id, req.partnerContext.partnerId],
        );
        return response.rows[0];
      });
      return res.status(201).json({
        data: { ...product, storeOpen: isOpenNow(product).open },
        meta: { requestId: req.requestId },
      });
    } catch (error) {
      return error instanceof PartnerApiError ? sendError(res, req, error) : next(error);
    }
  });

  router.get('/partner/products/:id', async (req, res, next) => {
    try {
      const id = validateUuid(req.params.id, 'id');
      if (!databasePool) {
        throw new PartnerApiError(503, 'DATABASE_UNAVAILABLE', 'Products are temporarily unavailable.');
      }
      const result = await databasePool.query(
        `${PRODUCT_SELECT}
         WHERE pr.id = $1::uuid AND pr.partner_id = $2::uuid
         LIMIT 1`,
        [id, req.partnerContext.partnerId],
      );
      if (result.rows.length !== 1) {
        throw new PartnerApiError(404, 'PRODUCT_NOT_FOUND', 'Product not found.');
      }
      return res.status(200).json({
        data: { ...result.rows[0], storeOpen: isOpenNow(result.rows[0]).open },
      });
    } catch (error) {
      return error instanceof PartnerApiError ? sendError(res, req, error) : next(error);
    }
  });

  router.patch('/partner/products/:id', async (req, res, next) => {
    try {
      const id = validateUuid(req.params.id, 'id');
      if (!databasePool) {
        throw new PartnerApiError(503, 'DATABASE_UNAVAILABLE', 'Products are temporarily unavailable.');
      }
      const profile = getPartnerTypeProfile(req.partnerContext.partnerType);
      if (!profile) throw new PartnerApiError(403, 'PARTNER_TYPE_UNSUPPORTED', 'Unsupported partner type.');
      const updatedProduct = await withTransaction(databasePool, async (client) => {
        const existingResult = await client.query(
          `SELECT
             pr.*,
             COALESCE((
               SELECT jsonb_agg(
                 jsonb_build_object(
                   'id', variant.id,
                   'label', variant.label,
                   'unit', variant.unit,
                   'quantity', variant.quantity,
                   'price_minor', variant.price_minor::text,
                   'stock', variant.stock,
                   'sku', variant.sku,
                   'is_available', variant.is_available,
                   'sort_order', variant.sort_order
                 ) ORDER BY variant.sort_order, variant.id
               )
               FROM app.product_variants AS variant
               WHERE variant.product_id = pr.id
             ), '[]'::jsonb) AS variants
           FROM app.products AS pr
           WHERE pr.id = $1::uuid AND pr.partner_id = $2::uuid
           FOR UPDATE`,
          [id, req.partnerContext.partnerId],
        );
        if (existingResult.rows.length !== 1) {
          throw new PartnerApiError(404, 'PRODUCT_NOT_FOUND', 'Product not found.');
        }
        const existing = existingResult.rows[0];
        existing.variants = (Array.isArray(existing.variants) ? existing.variants : []).map((variant) => ({
          ...variant,
          price_minor: Number(variant.price_minor),
        }));
        const input = validateProductInput(req.body ?? {}, profile, existing);
        if (input.shopId !== existing.shop_id) {
          throw new PartnerApiError(400, 'SHOP_CHANGE_NOT_ALLOWED', 'A product cannot be moved to another shop.');
        }
        await verifyCategory(
          client,
          input.categoryId,
          existing.shop_id,
          req.partnerContext.partnerId,
        );
        const summary = summarizeVariants(input.variants);
        if (req.body.variants !== undefined) {
          const cartReferences = await client.query(
            `SELECT 1
             FROM app.customer_cart_items AS item
             JOIN app.product_variants AS variant ON variant.id = item.variant_id
             WHERE variant.product_id = $1::uuid
             LIMIT 1`,
            [id],
          );
          if (cartReferences.rows.length > 0) {
            throw new PartnerApiError(
              409,
              'PRODUCT_VARIANTS_IN_CART',
              'Variants cannot be replaced while customers have them in carts.',
            );
          }
          await client.query(
            `DELETE FROM app.product_variants
             WHERE product_id = $1::uuid AND partner_id = $2::uuid`,
            [id, req.partnerContext.partnerId],
          );
        }
        await client.query(
          `UPDATE app.products
           SET category_id = $3::uuid,
               name = $4,
               description = $5,
               price_minor = $6,
               inventory_quantity = $7,
               is_available = $8,
               attributes = $9::jsonb,
               image_url = $10,
               updated_at = now()
           WHERE id = $1::uuid AND partner_id = $2::uuid`,
          [
            id,
            req.partnerContext.partnerId,
            input.categoryId,
            input.name,
            input.description,
            summary.priceMinor,
            summary.inventoryQuantity,
            summary.available,
            JSON.stringify(input.attributes),
            input.imageUrl,
          ],
        );
        if (req.body.variants !== undefined) {
          await insertVariants(
            client,
            input.variants,
            { id, partner_id: req.partnerContext.partnerId, shop_id: existing.shop_id },
          );
        }
        const response = await client.query(
          `${PRODUCT_SELECT}
           WHERE pr.id = $1::uuid AND pr.partner_id = $2::uuid`,
          [id, req.partnerContext.partnerId],
        );
        return response.rows[0];
      });
      return res.status(200).json({
        data: { ...updatedProduct, storeOpen: isOpenNow(updatedProduct).open },
      });
    } catch (error) {
      return error instanceof PartnerApiError ? sendError(res, req, error) : next(error);
    }
  });

  router.patch('/partner/products/:id/status', async (req, res, next) => {
    try {
      const id = validateUuid(req.params.id, 'id');
      if (!databasePool) {
        throw new PartnerApiError(503, 'DATABASE_UNAVAILABLE', 'Products are temporarily unavailable.');
      }
      const status = req.body?.status;
      if (!['active', 'archived'].includes(status)) {
        throw new PartnerApiError(400, 'INVALID_PRODUCT_STATUS', 'status must be active or archived.');
      }
      const result = await databasePool.query(
        `UPDATE app.products
         SET status = $3, updated_at = now()
         WHERE id = $1::uuid AND partner_id = $2::uuid
         RETURNING id, partner_id, shop_id, status, is_available`,
        [id, req.partnerContext.partnerId, status],
      );
      if (result.rows.length !== 1) {
        throw new PartnerApiError(404, 'PRODUCT_NOT_FOUND', 'Product not found.');
      }
      return res.status(200).json({ data: result.rows[0] });
    } catch (error) {
      return error instanceof PartnerApiError ? sendError(res, req, error) : next(error);
    }
  });

  router.get('/partner/orders', async (req, res, next) => {
    try {
      if (!databasePool) {
        throw new PartnerApiError(503, 'DATABASE_UNAVAILABLE', 'Orders are temporarily unavailable.');
      }
      const page = parsePage(req.query);
      const status = req.query.status;
      if (
        status !== undefined &&
        !ORDER_STATUSES.includes(status) &&
        !['accepted', 'ready'].includes(status)
      ) {
        throw new PartnerApiError(400, 'INVALID_ORDER_STATUS', 'status is not supported.');
      }
      const databaseStatus = status === undefined
        ? null
        : ORDER_STATUS_TO_DATABASE[status] ?? status;
      const result = await databasePool.query(
        `SELECT
           o.id, o.partner_id, o.shop_id, s.name AS shop_name, o.status,
           o.currency, o.items_subtotal_minor::text AS items_subtotal_minor,
           CASE WHEN o.status IN ('cancelled', 'rejected') THEN '0'
             ELSE COALESCE((SELECT sum(oi.line_total_minor - oi.commission_minor)
               FROM app.order_items AS oi
               WHERE oi.order_id = o.id AND oi.partner_id = o.partner_id), 0)::text
           END AS "partnerEarningMinor",
           o.delivery_fee_minor::text AS delivery_fee_minor,
           o.discount_minor::text AS discount_minor,
           o.total_minor::text AS total_minor,
           o.delivery_address_snapshot, o.placed_at, o.updated_at,
           (SELECT count(*)::integer FROM app.order_items AS oi
            WHERE oi.order_id = o.id AND oi.partner_id = o.partner_id) AS item_count
         FROM app.orders AS o
         JOIN app.shops AS s
           ON s.id = o.shop_id AND s.partner_id = o.partner_id
         WHERE o.partner_id = $1::uuid
           AND ($2::text IS NULL OR o.status = $2)
         ORDER BY o.placed_at DESC, o.id DESC
         LIMIT $3 OFFSET $4`,
        [req.partnerContext.partnerId, databaseStatus, page.limit, page.offset],
      );
      const countResult = await databasePool.query(
        `SELECT count(*)::integer AS total
         FROM app.orders AS o
         WHERE o.partner_id = $1::uuid
           AND ($2::text IS NULL OR o.status = $2)`,
        [req.partnerContext.partnerId, databaseStatus],
      );
      return res.status(200).json({
        data: result.rows,
        pagination: { ...page, total: countResult.rows[0].total },
      });
    } catch (error) {
      return error instanceof PartnerApiError ? sendError(res, req, error) : next(error);
    }
  });

  router.get('/partner/orders/:id', async (req, res, next) => {
    try {
      if (!databasePool) {
        throw new PartnerApiError(503, 'DATABASE_UNAVAILABLE', 'Orders are temporarily unavailable.');
      }
      const id = validateUuid(req.params.id, 'id');
      const orderResult = await databasePool.query(
        `SELECT
           o.id, o.partner_id, o.shop_id, s.name AS shop_name, o.status,
           o.currency, o.items_subtotal_minor::text AS items_subtotal_minor,
           CASE WHEN o.status IN ('cancelled', 'rejected') THEN '0'
             ELSE COALESCE((SELECT sum(oi.line_total_minor - oi.commission_minor)
               FROM app.order_items AS oi
               WHERE oi.order_id = o.id AND oi.partner_id = o.partner_id), 0)::text
           END AS "partnerEarningMinor",
           o.delivery_fee_minor::text AS delivery_fee_minor,
           o.discount_minor::text AS discount_minor,
           o.total_minor::text AS total_minor,
           o.delivery_address_snapshot, o.placed_at, o.updated_at
         FROM app.orders AS o
         JOIN app.shops AS s
           ON s.id = o.shop_id AND s.partner_id = o.partner_id
         WHERE o.id = $1::uuid AND o.partner_id = $2::uuid
         LIMIT 1`,
        [id, req.partnerContext.partnerId],
      );
      if (orderResult.rows.length !== 1) {
        throw new PartnerApiError(404, 'ORDER_NOT_FOUND', 'Order not found.');
      }
      const itemResult = await databasePool.query(
        `SELECT
           product_id, product_name_snapshot, sku_snapshot,
           unit_price_minor::text AS unit_price_minor, quantity,
           line_total_minor::text AS line_total_minor, currency, variant_snapshot
         FROM app.order_items
         WHERE order_id = $1::uuid AND partner_id = $2::uuid
         ORDER BY created_at, id`,
        [id, req.partnerContext.partnerId],
      );
      return res.status(200).json({
        data: { ...orderResult.rows[0], items: itemResult.rows },
      });
    } catch (error) {
      return error instanceof PartnerApiError ? sendError(res, req, error) : next(error);
    }
  });

  router.patch('/partner/orders/:id/status', async (req, res, next) => {
    try {
      if (!databasePool) {
        throw new PartnerApiError(503, 'DATABASE_UNAVAILABLE', 'Orders are temporarily unavailable.');
      }
      const id = validateUuid(req.params.id, 'id');
      const nextStatus = req.body?.status;
      if (
        typeof nextStatus !== 'string' ||
        (!ORDER_STATUSES.includes(nextStatus) &&
          !['accepted', 'ready'].includes(nextStatus))
      ) {
        throw new PartnerApiError(400, 'INVALID_ORDER_STATUS', 'status is not supported.');
      }
      const databaseNextStatus = ORDER_STATUS_TO_DATABASE[nextStatus] ?? nextStatus;
      const updated = await withTransaction(databasePool, async (client) => {
        const currentResult = await client.query(
          `SELECT id, status
           FROM app.orders
           WHERE id = $1::uuid AND partner_id = $2::uuid
           FOR UPDATE`,
          [id, req.partnerContext.partnerId],
        );
        if (currentResult.rows.length !== 1) {
          throw new PartnerApiError(404, 'ORDER_NOT_FOUND', 'Order not found.');
        }
        const databaseCurrentStatus = currentResult.rows[0].status;
        const currentStatus = databaseCurrentStatus === 'confirmed'
          ? 'accepted'
          : databaseCurrentStatus === 'ready_for_pickup'
            ? 'ready'
            : databaseCurrentStatus;
        if (!(ORDER_TRANSITIONS[currentStatus] ?? []).includes(nextStatus)) {
          throw new PartnerApiError(
            409,
            'INVALID_ORDER_TRANSITION',
            `Order cannot transition from ${currentStatus} to ${nextStatus}.`,
          );
        }
        const result = await client.query(
          `UPDATE app.orders
           SET status = $3, updated_at = now()
           WHERE id = $1::uuid AND partner_id = $2::uuid
           RETURNING id, partner_id, shop_id, status, currency, updated_at`,
          [id, req.partnerContext.partnerId, databaseNextStatus],
        );
        const earningResult = await client.query(
          `SELECT CASE WHEN o.status IN ('cancelled', 'rejected') THEN '0'
             ELSE COALESCE((SELECT sum(oi.line_total_minor - oi.commission_minor)
               FROM app.order_items AS oi
               WHERE oi.order_id = o.id AND oi.partner_id = o.partner_id), 0)::text
           END AS "partnerEarningMinor"
           FROM app.orders AS o
           WHERE o.id = $1::uuid AND o.partner_id = $2::uuid`,
          [id, req.partnerContext.partnerId],
        );
        return { ...result.rows[0], ...earningResult.rows[0] };
      });
      return res.status(200).json({ data: updated });
    } catch (error) {
      return error instanceof PartnerApiError ? sendError(res, req, error) : next(error);
    }
  });

  return router;
}

module.exports = {
  ORDER_STATUSES,
  ORDER_TRANSITIONS,
  PartnerApiError,
  createPartnerProductOrderRouter,
  parsePage,
  validateAttributes,
  validateProductInput,
  validateVariants,
};
