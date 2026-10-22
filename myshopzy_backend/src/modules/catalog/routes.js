const express = require('express');
const { isOpenNow } = require('../shared/store-hours');
const { getPartnerTypeProfile } = require('../partner-types/profiles');

const PARTNER_TYPE_PATTERN = /^[a-z][a-z0-9_]{0,39}$/;
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function queryString(value, name, { maxLength = 100 } = {}) {
  if (value === undefined) return { value: null };
  if (typeof value !== 'string') {
    return { error: `${name} must be a single string value.` };
  }

  const normalized = value.trim();
  if (!normalized) return { error: `${name} must not be empty.` };
  if (normalized.length > maxLength) {
    return { error: `${name} must be at most ${maxLength} characters.` };
  }

  return { value: normalized };
}

function queryUuid(value, name) {
  const parsed = queryString(value, name, { maxLength: 36 });
  if (parsed.error) return parsed;
  if (parsed.value === null) return parsed;
  if (!UUID_PATTERN.test(parsed.value)) {
    return { error: `${name} must be a valid UUID.` };
  }
  return parsed;
}

function pagination(query) {
  const limitValue = queryString(query.limit, 'limit', { maxLength: 3 });
  if (limitValue.error) return limitValue;
  const offsetValue = queryString(query.offset, 'offset', { maxLength: 16 });
  if (offsetValue.error) return offsetValue;

  const limit = limitValue.value === null ? DEFAULT_LIMIT : Number(limitValue.value);
  const offset = offsetValue.value === null ? 0 : Number(offsetValue.value);

  if (
    (limitValue.value !== null && !/^\d+$/.test(limitValue.value)) ||
    !Number.isInteger(limit) ||
    limit < 1 ||
    limit > MAX_LIMIT
  ) {
    return { error: `limit must be an integer between 1 and ${MAX_LIMIT}.` };
  }
  if (
    (offsetValue.value !== null && !/^\d+$/.test(offsetValue.value)) ||
    !Number.isSafeInteger(offset) ||
    offset < 0
  ) {
    return { error: 'offset must be a non-negative safe integer.' };
  }

  return { value: { limit, offset } };
}

function sendValidationError(res, message) {
  res.status(400).json({
    error: { code: 'INVALID_REQUEST', message },
  });
}

function sendDatabaseUnavailable(res) {
  res.status(503).json({
    error: {
      code: 'DATABASE_UNAVAILABLE',
      message: 'The catalog is temporarily unavailable.',
    },
  });
}

function partnerTypeDisplayName(partnerType) {
  const profile = getPartnerTypeProfile(partnerType);
  if (profile) return profile.label;
  return partnerType
    .split('_')
    .map((word) => word[0].toUpperCase() + word.slice(1))
    .join(' ');
}

function createCatalogRouter({ databasePool, now = () => new Date() }) {
  const router = express.Router();

  router.get('/partner-categories', async (req, res, next) => {
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const result = await databasePool.query(
        `SELECT partner_type, COUNT(*)::integer AS partner_count
         FROM app.partners
         WHERE is_active = true
         GROUP BY partner_type
         ORDER BY partner_type`,
      );
      return res.status(200).json({
        data: result.rows.map((row) => ({
          partner_type: row.partner_type,
          display_name: partnerTypeDisplayName(row.partner_type),
          partner_count: row.partner_count,
        })),
      });
    } catch (error) {
      return next(error);
    }
  });

  router.get('/shops', async (req, res, next) => {
    const partnerType = queryString(req.query.partnerType, 'partnerType', {
      maxLength: 40,
    });
    const search = queryString(req.query.q, 'q');
    const page = pagination(req.query);
    const validationError = partnerType.error || search.error || page.error;

    if (validationError) return sendValidationError(res, validationError);
    if (partnerType.value && !PARTNER_TYPE_PATTERN.test(partnerType.value)) {
      return sendValidationError(
        res,
        'partnerType must be a lowercase identifier using letters, digits, or underscores.',
      );
    }
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const result = await databasePool.query(
        `SELECT
           s.id,
           s.partner_id,
           s.name,
           s.slug,
           s.address,
           s.operating_details,
           p.timezone,
           p.name AS partner_name,
           p.partner_type
         FROM app.shops AS s
         JOIN app.partners AS p ON p.id = s.partner_id
         WHERE s.status = 'active'
           AND p.status = 'approved'
           AND ($1::text IS NULL OR p.partner_type = $1)
           AND ($2::text IS NULL OR s.name ILIKE '%' || $2 || '%'
                OR p.name ILIKE '%' || $2 || '%')
         ORDER BY s.name, s.id
         LIMIT $3 OFFSET $4`,
        [
          partnerType.value,
          search.value,
          page.value.limit,
          page.value.offset,
        ],
      );

      return res.status(200).json({
        data: result.rows.map((shop) => ({
          ...shop,
          storeOpen: isOpenNow(shop, now()).open,
        })),
        pagination: page.value,
      });
    } catch (error) {
      return next(error);
    }
  });

  router.get('/shops/:shopId/categories', async (req, res, next) => {
    if (!UUID_PATTERN.test(req.params.shopId)) {
      return sendValidationError(res, 'shopId must be a valid UUID.');
    }
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const result = await databasePool.query(
        `SELECT
           c.id,
           c.shop_id,
           c.parent_category_id,
           c.name,
           c.slug,
           c.sort_order
         FROM app.shops AS s
         JOIN app.partners AS p ON p.id = s.partner_id
         LEFT JOIN app.categories AS c
           ON c.shop_id = s.id AND c.is_active = true
         WHERE s.id = $1
           AND s.status = 'active'
           AND p.status = 'approved'
         ORDER BY c.sort_order NULLS LAST, c.name`,
        [req.params.shopId],
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'NOT_FOUND', message: 'Shop not found.' },
        });
      }

      return res.status(200).json({
        data: result.rows.filter((row) => row.id !== null),
      });
    } catch (error) {
      return next(error);
    }
  });

  router.get('/products', async (req, res, next) => {
    const shopId = queryUuid(req.query.shopId, 'shopId');
    const categoryId = queryUuid(req.query.categoryId, 'categoryId');
    const partnerType = queryString(req.query.partnerType, 'partnerType', {
      maxLength: 40,
    });
    const search = queryString(req.query.q, 'q');
    const page = pagination(req.query);
    const validationError =
      shopId.error ||
      categoryId.error ||
      partnerType.error ||
      search.error ||
      page.error;

    if (validationError) return sendValidationError(res, validationError);
    if (partnerType.value && !PARTNER_TYPE_PATTERN.test(partnerType.value)) {
      return sendValidationError(
        res,
        'partnerType must be a lowercase identifier using letters, digits, or underscores.',
      );
    }
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const result = await databasePool.query(
        `SELECT
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
         WHERE pr.status = 'active'
           AND pr.is_available = true
           AND s.status = 'active'
           AND p.status = 'approved'
           AND ($1::uuid IS NULL OR pr.shop_id = $1)
           AND ($2::uuid IS NULL OR pr.category_id = $2)
           AND ($3::text IS NULL OR p.partner_type = $3)
           AND ($4::text IS NULL OR pr.name ILIKE '%' || $4 || '%'
                OR pr.description ILIKE '%' || $4 || '%')
         ORDER BY pr.name, pr.id
         LIMIT $5 OFFSET $6`,
        [
          shopId.value,
          categoryId.value,
          partnerType.value,
          search.value,
          page.value.limit,
          page.value.offset,
        ],
      );

      return res.status(200).json({
        data: result.rows.map((product) => ({
          ...product,
          storeOpen: isOpenNow(product).open,
        })),
        pagination: page.value,
      });
    } catch (error) {
      return next(error);
    }
  });

  router.get('/products/:productId', async (req, res, next) => {
    if (!UUID_PATTERN.test(req.params.productId)) {
      return sendValidationError(res, 'productId must be a valid UUID.');
    }
    if (!databasePool) return sendDatabaseUnavailable(res);

    try {
      const result = await databasePool.query(
        `SELECT
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
         WHERE pr.id = $1
           AND pr.status = 'active'
           AND pr.is_available = true
           AND s.status = 'active'
           AND p.status = 'approved'`,
        [req.params.productId],
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          error: { code: 'NOT_FOUND', message: 'Product not found.' },
        });
      }

      return res.status(200).json({
        data: {
          ...result.rows[0],
          storeOpen: isOpenNow(result.rows[0]).open,
        },
      });
    } catch (error) {
      return next(error);
    }
  });

  return router;
}

module.exports = { createCatalogRouter };
