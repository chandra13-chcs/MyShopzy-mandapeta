const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DEFAULT_LIMIT = 25;
const MAX_LIMIT = 100;
const LIST_KEYS = new Set(['limit', 'offset', 'q', 'sort']);

const resources = {
  orders: {
    table: `app.orders AS o
      JOIN app.customers AS c ON c.user_id = o.customer_user_id
      JOIN app.users AS cu ON cu.id = c.user_id
      JOIN app.partners AS p ON p.id = o.partner_id
      JOIN app.shops AS s ON s.id = o.shop_id AND s.partner_id = o.partner_id`,
    columns: `o.id AS "id",
      o.customer_user_id AS "customerId",
      cu.display_name AS "customerName",
      o.partner_id AS "partnerId",
      p.name AS "partnerName",
      o.shop_id AS "shopId",
      s.name AS "shopName",
      o.status AS "status",
      o.currency AS "currency",
      o.items_subtotal_minor AS "itemsSubtotalMinor",
      o.commission_minor AS "commissionMinor",
      CASE WHEN o.status IN ('cancelled', 'rejected') THEN '0'
        ELSE COALESCE((SELECT sum(oi.line_total_minor - oi.commission_minor)
          FROM app.order_items AS oi WHERE oi.order_id = o.id), 0)::text
      END AS "partnerEarningMinor",
      o.delivery_fee_minor AS "deliveryFeeMinor",
      o.discount_minor AS "discountMinor",
      o.total_minor AS "totalMinor",
      o.placed_at AS "placedAt"`,
    sorts: {
      placedAt: 'o.placed_at',
      totalMinor: 'o.total_minor',
      status: 'o.status',
      orderId: 'o.id',
    },
    filters: {
      status: {
        field: 'o.status',
        type: 'text',
        allowedValues: new Set([
          'placed',
          'confirmed',
          'preparing',
          'ready_for_pickup',
          'picked_up',
          'delivered',
          'cancelled',
          'rejected',
        ]),
      },
      partnerId: { field: 'o.partner_id', type: 'uuid' },
      customerId: { field: 'o.customer_user_id', type: 'uuid' },
      from: { field: 'o.placed_at', type: 'date', operator: '>=' },
      to: { field: 'o.placed_at', type: 'date', operator: '<' },
    },
    defaultSort: 'placedAt:desc',
    idField: 'o.id',
    idSort: 'o.id',
    detailColumns: `o.id AS "id",
      o.customer_user_id AS "customerId",
      cu.display_name AS "customerName",
      o.partner_id AS "partnerId",
      p.name AS "partnerName",
      o.shop_id AS "shopId",
      s.name AS "shopName",
      o.status AS "status",
      o.currency AS "currency",
      o.items_subtotal_minor AS "itemsSubtotalMinor",
      o.commission_minor AS "commissionMinor",
      CASE WHEN o.status IN ('cancelled', 'rejected') THEN '0'
        ELSE COALESCE((SELECT sum(oi.line_total_minor - oi.commission_minor)
          FROM app.order_items AS oi WHERE oi.order_id = o.id), 0)::text
      END AS "partnerEarningMinor",
      o.delivery_fee_minor AS "deliveryFeeMinor",
      o.discount_minor AS "discountMinor",
      o.total_minor AS "totalMinor",
      o.placed_at AS "placedAt"`,
  },
  customers: {
    table: `app.customers AS c
      JOIN app.users AS u ON u.id = c.user_id`,
    baseWhere: `u.system_role = 'customer'`,
    columns: `u.id AS "id",
      u.display_name AS "displayName",
      u.status AS "status",
      u.created_at AS "createdAt"`,
    sorts: {
      displayName: 'u.display_name',
      createdAt: 'u.created_at',
      status: 'u.status',
      customerId: 'u.id',
    },
    filters: {
      status: { field: 'u.status', type: 'text', allowedValues: new Set(['active', 'suspended']) },
      from: { field: 'u.created_at', type: 'date', operator: '>=' },
      to: { field: 'u.created_at', type: 'date', operator: '<' },
    },
    defaultSort: 'createdAt:desc',
    idField: 'u.id',
    idSort: 'u.id',
    detailColumns: `u.id AS "id",
      u.display_name AS "displayName",
      u.status AS "status",
      u.created_at AS "createdAt"`,
  },
  partners: {
    table: 'app.partners AS p',
    columns: `p.id AS "id",
      p.name AS "name",
      p.partner_type AS "partnerType",
      p.status AS "status",
      p.created_at AS "createdAt"`,
    sorts: {
      name: 'p.name',
      partnerType: 'p.partner_type',
      status: 'p.status',
      createdAt: 'p.created_at',
      partnerId: 'p.id',
    },
    filters: {
      partnerType: {
        field: 'p.partner_type',
        type: 'text',
        allowedValues: new Set(['restaurant', 'grocery', 'meat_shop', 'other']),
      },
      status: {
        field: 'p.status',
        type: 'text',
        allowedValues: new Set(['pending', 'approved', 'suspended', 'rejected']),
      },
      from: { field: 'p.created_at', type: 'date', operator: '>=' },
      to: { field: 'p.created_at', type: 'date', operator: '<' },
    },
    defaultSort: 'createdAt:desc',
    idField: 'p.id',
    idSort: 'p.id',
    detailColumns: `p.id AS "id",
      p.name AS "name",
      p.partner_type AS "partnerType",
      p.status AS "status",
      p.created_at AS "createdAt"`,
  },
  products: {
    table: `app.products AS pr
      JOIN app.partners AS p ON p.id = pr.partner_id
      JOIN app.shops AS s ON s.id = pr.shop_id AND s.partner_id = pr.partner_id
      LEFT JOIN app.categories AS c
        ON c.id = pr.category_id AND c.shop_id = pr.shop_id AND c.partner_id = pr.partner_id`,
    columns: `pr.id AS "id",
      pr.name AS "name",
      pr.partner_id AS "partnerId",
      p.name AS "partnerName",
      pr.shop_id AS "shopId",
      s.name AS "shopName",
      pr.category_id AS "categoryId",
      c.name AS "categoryName",
      pr.sku AS "sku",
      pr.price_minor AS "priceMinor",
      pr.currency AS "currency",
      pr.inventory_quantity AS "inventoryQuantity",
      pr.is_available AS "isAvailable",
      pr.status AS "status",
      pr.status AS "listingStatus",
      pr.created_at AS "createdAt"`,
    detailColumns: `pr.id AS "id",
      pr.name AS "name",
      pr.partner_id AS "partnerId",
      p.name AS "partnerName",
      pr.shop_id AS "shopId",
      s.name AS "shopName",
      pr.category_id AS "categoryId",
      c.name AS "categoryName",
      pr.sku AS "sku",
      pr.price_minor AS "priceMinor",
      pr.currency AS "currency",
      pr.inventory_quantity AS "inventoryQuantity",
      pr.is_available AS "isAvailable",
      pr.status AS "status",
      pr.status AS "listingStatus",
      pr.created_at AS "createdAt",
      pr.updated_at AS "updatedAt"`,
    sorts: {
      name: 'pr.name',
      priceMinor: 'pr.price_minor',
      status: 'pr.status',
      listingStatus: 'pr.status',
      createdAt: 'pr.created_at',
      productId: 'pr.id',
    },
    filters: {
      partnerId: { field: 'pr.partner_id', type: 'uuid' },
      shopId: { field: 'pr.shop_id', type: 'uuid' },
      categoryId: { field: 'pr.category_id', type: 'uuid' },
      status: { field: 'pr.status', type: 'text', allowedValues: new Set(['active', 'archived']) },
      availability: { field: 'pr.is_available', type: 'boolean' },
      from: { field: 'pr.created_at', type: 'date', operator: '>=' },
      to: { field: 'pr.created_at', type: 'date', operator: '<' },
    },
    defaultSort: 'createdAt:desc',
    idField: 'pr.id',
    idSort: 'pr.id',
  },
};

class QueryValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'QueryValidationError';
    this.status = 400;
    this.code = 'INVALID_REQUEST';
  }
}

function singleQueryValue(query, key, { maxLength = 100 } = {}) {
  const value = query[key];
  if (value === undefined) return null;
  if (typeof value !== 'string') {
    throw new QueryValidationError(`${key} must be a single string value.`);
  }
  const normalized = value.trim();
  if (!normalized) throw new QueryValidationError(`${key} must not be empty.`);
  if (normalized.length > maxLength) {
    throw new QueryValidationError(`${key} must be at most ${maxLength} characters.`);
  }
  return normalized;
}

function parseDate(value, key) {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|([+-])(\d{2}):(\d{2}))$/i.exec(value);
  if (!match) {
    throw new QueryValidationError(`${key} must be an RFC 3339 timestamp.`);
  }

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const hour = Number(match[4]);
  const minute = Number(match[5]);
  const second = Number(match[6]);
  const offsetHour = match[9] === undefined ? 0 : Number(match[9]);
  const offsetMinute = match[10] === undefined ? 0 : Number(match[10]);
  const leapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const daysInMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

  if (
    month < 1 || month > 12 ||
    day < 1 || day > daysInMonth[month - 1] ||
    hour > 23 || minute > 59 || second > 59 ||
    offsetHour > 23 || offsetMinute > 59 ||
    !Number.isFinite(Date.parse(value))
  ) {
    throw new QueryValidationError(`${key} must be a valid RFC 3339 timestamp.`);
  }
  return value;
}

function normalizeProductQuery(query) {
  const normalized = { ...query };
  for (const [apiName, queryName] of [
    ['listingStatus', 'status'],
    ['createdFrom', 'from'],
    ['createdTo', 'to'],
  ]) {
    if (normalized[apiName] === undefined) continue;
    if (normalized[queryName] !== undefined) {
      throw new QueryValidationError(`Use either ${apiName} or ${queryName}, not both.`);
    }
    normalized[queryName] = normalized[apiName];
    delete normalized[apiName];
  }
  return normalized;
}

function parseListQuery(resourceName, query = {}) {
  const definition = resources[resourceName];
  if (!definition) throw new TypeError(`Unknown read-only resource: ${resourceName}`);

  if (resourceName === 'products') query = normalizeProductQuery(query);

  const allowedKeys = new Set([
    ...LIST_KEYS,
    ...Object.keys(definition.filters),
  ]);
  const unsupportedKey = Object.keys(query).find((key) => !allowedKeys.has(key));
  if (unsupportedKey) {
    throw new QueryValidationError(`Unsupported query parameter: ${unsupportedKey}.`);
  }

  const limitText = singleQueryValue(query, 'limit', { maxLength: 3 });
  const offsetText = singleQueryValue(query, 'offset', { maxLength: 16 });
  if (limitText !== null && !/^\d+$/.test(limitText)) {
    throw new QueryValidationError('limit must be a decimal integer.');
  }
  if (offsetText !== null && !/^\d+$/.test(offsetText)) {
    throw new QueryValidationError('offset must be a decimal integer.');
  }

  const limit = limitText === null ? DEFAULT_LIMIT : Number(limitText);
  const offset = offsetText === null ? 0 : Number(offsetText);
  if (!Number.isInteger(limit) || limit < 1 || limit > MAX_LIMIT) {
    throw new QueryValidationError(`limit must be between 1 and ${MAX_LIMIT}.`);
  }
  if (!Number.isSafeInteger(offset) || offset < 0) {
    throw new QueryValidationError('offset must be a non-negative safe integer.');
  }

  const search = singleQueryValue(query, 'q');
  const sort = singleQueryValue(query, 'sort', { maxLength: 40 }) ?? definition.defaultSort;
  const sortMatch = /^([A-Za-z][A-Za-z0-9]*):(asc|desc)$/i.exec(sort);
  if (!sortMatch || !Object.hasOwn(definition.sorts, sortMatch[1])) {
    throw new QueryValidationError(`sort must be one of the supported ${resourceName} sort fields.`);
  }

  const filters = [];
  for (const [key, filter] of Object.entries(definition.filters)) {
    const raw = singleQueryValue(query, key, { maxLength: filter.type === 'date' ? 40 : 100 });
    if (raw === null) continue;
    let value = raw;
    if (filter.type === 'uuid' && !UUID_PATTERN.test(value)) {
      throw new QueryValidationError(`${key} must be a valid UUID.`);
    }
    if (filter.type === 'boolean') {
      if (value !== 'true' && value !== 'false') {
        throw new QueryValidationError(`${key} must be true or false.`);
      }
      value = value === 'true';
    }
    if (filter.type === 'date') value = parseDate(value, key);
    if (filter.allowedValues && !filter.allowedValues.has(value)) {
      throw new QueryValidationError(`${key} must be one of the supported values.`);
    }
    filters.push({ key, ...filter, value });
  }

  const from = filters.find((filter) => filter.key === 'from')?.value;
  const to = filters.find((filter) => filter.key === 'to')?.value;
  if (from && to && Date.parse(from) >= Date.parse(to)) {
    throw new QueryValidationError('from must be earlier than to.');
  }

  return {
    limit,
    offset,
    search,
    sortField: definition.sorts[sortMatch[1]],
    sortDirection: sortMatch[2].toUpperCase(),
    filters,
  };
}

function buildWhere(resourceName, parsed, parameters) {
  const definition = resources[resourceName];
  const clauses = [];
  const addParameter = (value) => {
    parameters.push(value);
    return `$${parameters.length}`;
  };

  if (parsed.search) {
    const placeholder = addParameter(parsed.search);
    if (resourceName === 'orders') {
      clauses.push(`(o.id::text ILIKE '%' || ${placeholder} || '%' OR cu.display_name ILIKE '%' || ${placeholder} || '%' OR p.name ILIKE '%' || ${placeholder} || '%')`);
    } else if (resourceName === 'customers') {
      clauses.push(`(u.id::text ILIKE '%' || ${placeholder} || '%' OR u.display_name ILIKE '%' || ${placeholder} || '%')`);
    } else if (resourceName === 'partners') {
      clauses.push(`(p.id::text ILIKE '%' || ${placeholder} || '%' OR p.name ILIKE '%' || ${placeholder} || '%')`);
    } else {
      clauses.push(`(pr.id::text ILIKE '%' || ${placeholder} || '%' OR pr.name ILIKE '%' || ${placeholder} || '%' OR pr.sku ILIKE '%' || ${placeholder} || '%' OR p.name ILIKE '%' || ${placeholder} || '%' OR s.name ILIKE '%' || ${placeholder} || '%')`);
    }
  }

  for (const filter of parsed.filters) {
    const operator = filter.operator ?? '=';
    clauses.push(`${filter.field} ${operator} ${addParameter(filter.value)}`);
  }
  return clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';
}

function safeTotal(row) {
  const total = Number(row?.total);
  if (!Number.isSafeInteger(total) || total < 0) {
    throw new RangeError('Database returned a total outside the safe integer range.');
  }
  return total;
}

async function listResource(databasePool, resourceName, query = {}) {
  if (!databasePool || typeof databasePool.query !== 'function') {
    const error = new Error('Database is unavailable.');
    error.status = 503;
    error.code = 'DATABASE_UNAVAILABLE';
    throw error;
  }
  const definition = resources[resourceName];
  if (!definition) throw new TypeError(`Unknown read-only resource: ${resourceName}`);
  const parsed = parseListQuery(resourceName, query);
  const countParameters = [];
  const filtersWhere = buildWhere(resourceName, parsed, countParameters);
  const where = [definition.baseWhere, filtersWhere.replace(/^WHERE\s+/, '')]
    .filter(Boolean)
    .join(' AND ')
    .replace(/^(.+)$/, 'WHERE $1');
  const countResult = await databasePool.query(
    `SELECT count(*)::text AS total FROM ${definition.table} ${where}`,
    countParameters,
  );
  const total = safeTotal(countResult.rows[0]);

  const parameters = [...countParameters, parsed.limit, parsed.offset];
  const rowsResult = await databasePool.query(
    `SELECT ${definition.columns}
     FROM ${definition.table}
     ${where}
     ORDER BY ${parsed.sortField} ${parsed.sortDirection}, ${definition.idSort} ASC
     LIMIT $${parameters.length - 1} OFFSET $${parameters.length}`,
    parameters,
  );
  return {
    data: rowsResult.rows,
    pagination: { limit: parsed.limit, offset: parsed.offset, total },
  };
}

async function getResource(databasePool, resourceName, id) {
  if (!databasePool || typeof databasePool.query !== 'function') {
    const error = new Error('Database is unavailable.');
    error.status = 503;
    error.code = 'DATABASE_UNAVAILABLE';
    throw error;
  }
  if (!Object.hasOwn(resources, resourceName)) {
    throw new TypeError(`Unknown read-only resource: ${resourceName}`);
  }
  if (typeof id !== 'string' || !UUID_PATTERN.test(id)) {
    throw new QueryValidationError('id must be a valid UUID.');
  }
  const definition = resources[resourceName];
  const result = await databasePool.query(
    `SELECT ${definition.detailColumns} FROM ${definition.table} WHERE ${definition.idField} = $1${definition.baseWhere ? ` AND ${definition.baseWhere}` : ''}`,
    [id],
  );
  const row = result.rows[0];
  if (!row) return null;

  if (resourceName === 'orders') {
    const items = await databasePool.query(
      `SELECT product_id AS "productId",
        product_name_snapshot AS "productName",
        sku_snapshot AS "sku",
        unit_price_minor AS "unitPriceMinor",
        quantity AS "quantity",
        line_total_minor AS "lineTotalMinor",
        commission_bps AS "commissionBps",
        commission_minor AS "commissionMinor",
        currency AS "currency"
       FROM app.order_items
       WHERE order_id = $1
       ORDER BY id`,
      [id],
    );
    return {
      ...row,
      items: items.rows.map((item) => ({
        productId: item.productId,
        productName: item.productName,
        sku: item.sku,
        unitPriceMinor: item.unitPriceMinor,
        quantity: item.quantity,
        lineTotalMinor: item.lineTotalMinor,
        commissionBps: item.commissionBps,
        commissionMinor: item.commissionMinor,
        currency: item.currency,
      })),
    };
  }

  if (resourceName === 'partners') {
    const shops = await databasePool.query(
      `SELECT id, name, status, created_at AS "createdAt"
       FROM app.shops
       WHERE partner_id = $1
       ORDER BY name, id`,
      [id],
    );
    return { ...row, shops: shops.rows };
  }

  return row;
}

module.exports = {
  DEFAULT_LIMIT,
  MAX_LIMIT,
  QueryValidationError,
  getResource,
  listResource,
  parseListQuery,
};
