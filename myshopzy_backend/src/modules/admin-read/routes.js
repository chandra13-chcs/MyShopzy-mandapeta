const { randomUUID } = require('node:crypto');
const express = require('express');
const {
  LedgerError,
  confirmDue,
  listDues,
  recordPayment,
  waiveDue,
  withLedgerTransaction,
} = require('../dues/ledger');
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

function parseRequestObject(body, allowedFields) {
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return { error: 'Request body must be a JSON object.' };
  }
  const unsupported = Object.keys(body).find((key) => !allowedFields.has(key));
  return unsupported
    ? { error: `Unsupported request field: ${unsupported}.` }
    : { value: body };
}

function createAdminReadRouter({ databasePool, authenticateAdmin = null }) {
  const router = express.Router();
  router.use(requestIdMiddleware);
  router.use(requireAdminAuthentication(authenticateAdmin));

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
