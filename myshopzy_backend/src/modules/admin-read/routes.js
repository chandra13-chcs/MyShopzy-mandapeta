const { randomUUID } = require('node:crypto');
const express = require('express');
const {
  LedgerError,
  createPendingDue,
  confirmDue,
  listDues,
  recordPayment,
  waiveDue,
  withLedgerTransaction,
} = require('../dues/ledger');
const { DUE_POLICY } = require('../dues/policy');
const {
  getCategoryCommissionTotals,
  getResource,
  listResource,
} = require('./queries');
const {
  toAuthenticationRequiredHttpResponse,
  toDetailHttpResponse,
  toErrorHttpResponse,
  toListHttpResponse,
} = require('./http-adapter');

const REQUEST_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$/;
const ADMIN_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DUE_STATUSES = new Set(['pending_review', 'confirmed', 'paid', 'waived']);
const SUPPORT_OUTCOMES = new Set([
  'customer_reached',
  'customer_unreachable',
  'customer_refused',
]);

const resourceRoutes = [
  ['/admin/orders', 'orders'],
  ['/admin/customers', 'customers'],
  ['/admin/partners', 'partners'],
  ['/admin/catalog/products', 'products'],
];

function requestIdMiddleware(req, res, next) {
  const suppliedRequestId = req.get('x-request-id');
  req.requestId = suppliedRequestId && REQUEST_ID_PATTERN.test(suppliedRequestId)
    ? suppliedRequestId
    : randomUUID();
  res.set('X-Request-ID', req.requestId);
  next();
}

function unauthorizedResponse(res, requestId) {
  return sendAdapterResponse(
    res,
    toAuthenticationRequiredHttpResponse(requestId),
  );
}

function requireAdminAuthentication(authenticateAdmin) {
  return (req, res, next) => {
    if (typeof authenticateAdmin !== 'function') {
      return unauthorizedResponse(res, req.requestId);
    }
    try {
      const result = authenticateAdmin(req, res, (error) => {
        if (error) return next(error);
        if (res.headersSent) return;
        if (!ADMIN_ID_PATTERN.test(req.auth?.adminUserId ?? '')) {
          return unauthorizedResponse(res, req.requestId);
        }
        return next();
      });
      if (result && typeof result.catch === 'function') {
        result.catch(next);
      }
      return result;
    } catch (error) {
      return next(error);
    }
  };
}

function sendAdapterResponse(res, response) {
  return res.status(response.status).json(response.body);
}

function sendDuesError(res, error, requestId) {
  if (!(error instanceof LedgerError)) return null;
  const body = { code: error.code, message: error.message };
  if (error.details !== undefined) body.details = error.details;
  return res.status(error.status).json({
    error: body,
    meta: { requestId },
  });
}

function parseDuesPage(query) {
  const limit = query.limit === undefined ? 20 : Number(query.limit);
  const offset = query.offset === undefined ? 0 : Number(query.offset);
  if (
    !Number.isInteger(limit) ||
    limit < 1 ||
    limit > 100 ||
    !Number.isSafeInteger(offset) ||
    offset < 0
  ) {
    return { error: 'limit must be 1..100 and offset must be a non-negative integer.' };
  }
  if (query.status !== undefined && !DUE_STATUSES.has(query.status)) {
    return { error: 'status must be pending_review, confirmed, paid, or waived.' };
  }
  return { value: { limit, offset, status: query.status ?? null } };
}

function parseEscalationPage(query) {
  const limit = query.limit === undefined ? 20 : Number(query.limit);
  const offset = query.offset === undefined ? 0 : Number(query.offset);
  if (
    !Number.isInteger(limit) ||
    limit < 1 ||
    limit > 100 ||
    !Number.isSafeInteger(offset) ||
    offset < 0
  ) {
    return { error: 'limit must be 1..100 and offset must be a non-negative integer.' };
  }
  return { value: { limit, offset } };
}

function sendSupportError(res, status, code, message, requestId, details = {}) {
  return res.status(status).json({
    error: { code, message, ...details },
    meta: { requestId },
  });
}

function parseRequestObject(body, allowedFields) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'Request body must be a JSON object.' };
  }
  const unsupported = Object.keys(body).find((key) => !allowedFields.has(key));
  return unsupported
    ? { error: `Unsupported request field: ${unsupported}.` }
    : { value: body };
}

function createAdminReadRouter({
  databasePool,
  authenticateAdmin = null,
  supportEscalationMinutes = 10,
}) {
  const router = express.Router();
  router.use(requestIdMiddleware);
  router.use('/admin', requireAdminAuthentication(authenticateAdmin));

  router.get('/admin/catalog/category-commission-totals', async (req, res, next) => {
    try {
      const data = await getCategoryCommissionTotals(databasePool);
      return res.status(200).json({ data, meta: { requestId: req.requestId } });
    } catch (error) {
      try {
        return sendAdapterResponse(res, toErrorHttpResponse(error, req.requestId));
      } catch (adapterError) {
        return next(adapterError);
      }
    }
  });

  router.get('/admin/dues', async (req, res, next) => {
    const page = parseDuesPage(req.query);
    if (page.error) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: page.error },
        meta: { requestId: req.requestId },
      });
    }
    try {
      const dues = await listDues(databasePool, page.value);
      return res.status(200).json({
        data: { dues },
        meta: {
          requestId: req.requestId,
          pagination: {
            limit: page.value.limit,
            offset: page.value.offset,
          },
        },
      });
    } catch (error) {
      return next(error);
    }
  });

  router.get('/admin/support/escalations', async (req, res, next) => {
    const page = parseEscalationPage(req.query);
    if (page.error) {
      return sendSupportError(
        res,
        400,
        'INVALID_REQUEST',
        page.error,
        req.requestId,
      );
    }
    if (!databasePool) {
      return sendSupportError(
        res,
        503,
        'DATABASE_UNAVAILABLE',
        'Support escalations are temporarily unavailable.',
        req.requestId,
      );
    }
    try {
      const result = await withLedgerTransaction(databasePool, async (client) => {
        const eligibleWhere = `o.rider_arrived_at <= now() - ($1 * interval '1 minute')
          AND o.status NOT IN ('delivered', 'delivery_failed')
          AND NOT EXISTS (
            SELECT 1 FROM app.order_support_resolutions AS resolution
            WHERE resolution.order_id = o.id
          )`;
        const totalResult = await client.query(
          `SELECT COUNT(*)::int AS total
           FROM app.orders AS o
           WHERE ${eligibleWhere}`,
          [supportEscalationMinutes],
        );
        await client.query(
          `WITH page AS (
             SELECT o.id
             FROM app.orders AS o
             WHERE ${eligibleWhere}
             ORDER BY o.rider_arrived_at, o.id
             LIMIT $2 OFFSET $3
             FOR UPDATE
           )
           UPDATE app.orders AS o
           SET support_escalated_at = COALESCE(o.support_escalated_at, now())
           FROM page
           WHERE o.id = page.id`,
          [supportEscalationMinutes, page.value.limit, page.value.offset],
        );
        const escalations = await client.query(
          `SELECT o.id AS "orderId",
                  o.rider_arrived_at AS "riderArrivedAt",
                  o.support_escalated_at AS "supportEscalatedAt",
                  cu.phone AS "customerPhone",
                  ru.display_name AS "riderName",
                  FLOOR(EXTRACT(EPOCH FROM (now() - o.rider_arrived_at)) / 60)::int
                    AS "minutesWaiting",
                  CASE WHEN due.id IS NULL THEN NULL
                    ELSE jsonb_build_object(
                      'entryId', due.id,
                      'amountMinor', due.amount_minor,
                      'currency', due.currency,
                      'reason', due.reason,
                      'status', 'pending_review',
                      'createdAt', due.created_at
                    )
                  END AS due
           FROM app.orders AS o
           JOIN app.users AS cu ON cu.id = o.customer_user_id
           LEFT JOIN app.users AS ru ON ru.id = o.rider_id
           LEFT JOIN LATERAL (
             SELECT entry.id, entry.amount_minor::text AS amount_minor,
                    entry.currency, entry.reason, entry.created_at
             FROM app.customer_ledger_entries AS entry
             WHERE entry.order_id = o.id
               AND entry.entry_type = 'due_pending_review'
               AND entry.related_entry_id IS NULL
             ORDER BY entry.created_at DESC, entry.id
             LIMIT 1
           ) AS due ON true
           WHERE ${eligibleWhere}
           ORDER BY o.rider_arrived_at, o.id
           LIMIT $2 OFFSET $3`,
          [supportEscalationMinutes, page.value.limit, page.value.offset],
        );
        return {
          escalations: escalations.rows,
          total: totalResult.rows[0].total,
        };
      });
      return res.status(200).json({
        data: { escalations: result.escalations },
        meta: {
          requestId: req.requestId,
          pagination: {
            limit: page.value.limit,
            offset: page.value.offset,
            total: result.total,
          },
        },
      });
    } catch (error) {
      return next(error);
    }
  });

  router.post('/admin/support/escalations/:orderId/resolve', async (req, res, next) => {
    if (!ADMIN_ID_PATTERN.test(req.params.orderId)) {
      return sendSupportError(
        res,
        400,
        'INVALID_REQUEST',
        'orderId must be a valid UUID.',
        req.requestId,
      );
    }
    const body = parseRequestObject(
      req.body,
      new Set(['supportReference', 'outcome', 'note']),
    );
    const supportReference =
      typeof body.value?.supportReference === 'string'
        ? body.value.supportReference.trim()
        : '';
    if (
      body.error ||
      supportReference.length < 3 ||
      supportReference.length > 100 ||
      !SUPPORT_OUTCOMES.has(body.value?.outcome) ||
      (body.value?.note !== undefined &&
        (typeof body.value.note !== 'string' ||
          body.value.note.trim().length > 300))
    ) {
      return sendSupportError(
        res,
        400,
        'INVALID_REQUEST',
        body.error ??
          'supportReference must be 3..100 characters, outcome must be a supported value, and note must be at most 300 characters.',
        req.requestId,
      );
    }
    const note =
      body.value.note === undefined ? null : body.value.note.trim();
    if (!databasePool) {
      return sendSupportError(
        res,
        503,
        'DATABASE_UNAVAILABLE',
        'Support escalations are temporarily unavailable.',
        req.requestId,
      );
    }

    try {
      const result = await withLedgerTransaction(databasePool, async (client) => {
        const orderResult = await client.query(
          `SELECT o.id, o.customer_user_id, o.rider_id, o.status,
                  o.payment_method, o.total_minor::text AS total_minor,
                  o.currency, o.rider_arrived_at,
                  (o.rider_arrived_at <= now() - ($2 * interval '1 minute'))
                    AS support_wait_elapsed,
                  GREATEST(0, CEIL(EXTRACT(EPOCH FROM (
                    o.rider_arrived_at + ($2 * interval '1 minute') - now()
                  )))::int) AS remaining_seconds
           FROM app.orders AS o
           WHERE o.id = $1
           FOR UPDATE OF o`,
          [req.params.orderId, supportEscalationMinutes],
        );
        if (orderResult.rows.length === 0) {
          return { error: { status: 404, code: 'ORDER_NOT_FOUND', message: 'Order not found.' } };
        }
        const order = orderResult.rows[0];
        if (['delivered', 'delivery_failed'].includes(order.status)) {
          return {
            error: {
              status: 409,
              code: 'ORDER_NOT_ESCALATABLE',
              message: 'Delivered or failed orders cannot be resolved as support escalations.',
            },
          };
        }
        if (!order.rider_arrived_at || !order.support_wait_elapsed) {
          return {
            error: {
              status: 409,
              code: 'SUPPORT_WAIT_NOT_ELAPSED',
              message: 'The support waiting period has not elapsed.',
              details: {
                remainingSeconds: order.rider_arrived_at
                  ? order.remaining_seconds
                  : supportEscalationMinutes * 60,
              },
            },
          };
        }
        const previous = await client.query(
          `SELECT order_id FROM app.order_support_resolutions
           WHERE order_id = $1`,
          [order.id],
        );
        if (previous.rows.length) {
          return {
            error: {
              status: 409,
              code: 'SUPPORT_ALREADY_RESOLVED',
              message: 'This support escalation has already been resolved.',
            },
          };
        }
        await client.query(
          `UPDATE app.orders
           SET support_escalated_at = COALESCE(support_escalated_at, now())
           WHERE id = $1`,
          [order.id],
        );
        let due = null;
        if (
          order.payment_method === 'cod' &&
          body.value.outcome !== 'customer_reached'
        ) {
          const existingDue = await client.query(
            `SELECT id FROM app.customer_ledger_entries
             WHERE order_id = $1
               AND entry_type = 'due_pending_review'
               AND related_entry_id IS NULL
             LIMIT 1`,
            [order.id],
          );
          if (existingDue.rows.length === 0) {
            const amountMinor = DUE_POLICY.amountMinor(order);
            if (BigInt(amountMinor) <= 0n) {
              return {
                error: {
                  status: 409,
                  code: 'SUPPORT_DUE_AMOUNT_INVALID',
                  message: 'The order total cannot create a pending due.',
                },
              };
            }
            due = await createPendingDue(client, {
              customerUserId: order.customer_user_id,
              orderId: order.id,
              amountMinor,
              currency: order.currency,
              reason: body.value.outcome,
              createdByActor: `admin:${req.auth.adminUserId}`,
              note,
              evidence: {
                kind: 'support_resolution',
                outcome: body.value.outcome,
                supportReference,
              },
            });
          }
        }
        const resolutionResult = await client.query(
          `INSERT INTO app.order_support_resolutions (
             order_id, outcome, support_reference, note, resolved_by
           )
           VALUES ($1, $2, $3, $4, $5)
           RETURNING order_id AS "orderId", outcome, support_reference AS "supportReference",
                     note, resolved_by AS "resolvedBy", resolved_at AS "resolvedAt"`,
          [
            order.id,
            body.value.outcome,
            supportReference,
            note,
            req.auth.adminUserId,
          ],
        );
        return { resolution: resolutionResult.rows[0], due };
      });
      if (result.error) {
        return sendSupportError(
          res,
          result.error.status,
          result.error.code,
          result.error.message,
          req.requestId,
          result.error.details,
        );
      }
      return res.status(200).json({
        data: result,
        meta: { requestId: req.requestId },
      });
    } catch (error) {
      if (sendDuesError(res, error, req.requestId)) return;
      return next(error);
    }
  });

  router.post('/admin/dues/:entryId/confirm', async (req, res, next) => {
    if (!ADMIN_ID_PATTERN.test(req.params.entryId)) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: 'entryId must be a valid UUID.' },
        meta: { requestId: req.requestId },
      });
    }
    const body = parseRequestObject(req.body, new Set(['supportReference', 'note']));
    if (body.error) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: body.error },
        meta: { requestId: req.requestId },
      });
    }
    const { supportReference, note } = body.value;
    if (
      typeof supportReference !== 'string' ||
      supportReference.trim().length < 3 ||
      supportReference.trim().length > 100 ||
      (note !== undefined &&
        (typeof note !== 'string' || note.trim().length > 300))
    ) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: 'supportReference must be 3..100 characters and note must be at most 300 characters.',
        },
        meta: { requestId: req.requestId },
      });
    }
    try {
      const entry = await withLedgerTransaction(databasePool, (client) =>
        confirmDue(client, {
          dueEntryId: req.params.entryId,
          adminUserId: req.auth.adminUserId,
          supportReference: supportReference.trim(),
          note: note === undefined ? null : note.trim(),
        }),
      );
      return res.status(201).json({ data: { entry }, meta: { requestId: req.requestId } });
    } catch (error) {
      if (sendDuesError(res, error, req.requestId)) return;
      return next(error);
    }
  });

  router.post('/admin/dues/:entryId/waive', async (req, res, next) => {
    if (!ADMIN_ID_PATTERN.test(req.params.entryId)) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: 'entryId must be a valid UUID.' },
        meta: { requestId: req.requestId },
      });
    }
    const body = parseRequestObject(req.body, new Set(['reason']));
    if (
      body.error ||
      typeof body.value?.reason !== 'string' ||
      body.value.reason.trim().length < 1 ||
      body.value.reason.trim().length > 300
    ) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: body.error ?? 'reason is required and must be at most 300 characters.',
        },
        meta: { requestId: req.requestId },
      });
    }
    try {
      const entry = await withLedgerTransaction(databasePool, (client) =>
        waiveDue(client, {
          dueEntryId: req.params.entryId,
          adminUserId: req.auth.adminUserId,
          reason: body.value.reason.trim(),
        }),
      );
      return res.status(201).json({ data: { entry }, meta: { requestId: req.requestId } });
    } catch (error) {
      if (sendDuesError(res, error, req.requestId)) return;
      return next(error);
    }
  });

  router.post('/admin/customers/:customerId/dues/payments', async (req, res, next) => {
    if (!ADMIN_ID_PATTERN.test(req.params.customerId)) {
      return res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: 'customerId must be a valid UUID.' },
        meta: { requestId: req.requestId },
      });
    }
    const body = parseRequestObject(req.body, new Set(['amount', 'reference']));
    const amount = body.value?.amount;
    const reference =
      typeof body.value?.reference === 'string' ? body.value.reference.trim() : '';
    if (
      body.error ||
      !(
        (Number.isSafeInteger(amount) && amount > 0) ||
        (typeof amount === 'string' && /^[1-9][0-9]*$/.test(amount))
      ) ||
      reference.length < 1 ||
      reference.length > 100
    ) {
      return res.status(400).json({
        error: {
          code: 'INVALID_REQUEST',
          message: body.error ?? 'amount must be positive integer paise and reference is required.',
        },
        meta: { requestId: req.requestId },
      });
    }
    try {
      const entries = await withLedgerTransaction(databasePool, (client) =>
        recordPayment(client, {
          customerUserId: req.params.customerId,
          amountMinor: amount,
          reference,
          adminUserId: req.auth.adminUserId,
        }),
      );
      return res.status(201).json({ data: { entries }, meta: { requestId: req.requestId } });
    } catch (error) {
      if (sendDuesError(res, error, req.requestId)) return;
      return next(error);
    }
  });

  for (const [path, resource] of resourceRoutes) {
    router.get(path, async (req, res, next) => {
      try {
        return sendAdapterResponse(
          res,
          toListHttpResponse(
            await listResource(databasePool, resource, req.query),
            req.requestId,
          ),
        );
      } catch (error) {
        try {
          return sendAdapterResponse(res, toErrorHttpResponse(error, req.requestId));
        } catch (adapterError) {
          return next(adapterError);
        }
      }
    });

    router.get(`${path}/:id`, async (req, res, next) => {
      try {
        return sendAdapterResponse(
          res,
          toDetailHttpResponse(
            await getResource(databasePool, resource, req.params.id),
            req.requestId,
          ),
        );
      } catch (error) {
        try {
          return sendAdapterResponse(res, toErrorHttpResponse(error, req.requestId));
        } catch (adapterError) {
          return next(adapterError);
        }
      }
    });
  }

  router.use((error, req, res, next) => {
    if (res.headersSent) return next(error);
    return sendAdapterResponse(res, toErrorHttpResponse(error, req.requestId));
  });

  return router;
}

module.exports = { createAdminReadRouter };
