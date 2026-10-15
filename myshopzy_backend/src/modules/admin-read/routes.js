const { randomUUID } = require('node:crypto');
const express = require('express');
const {
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

function createAdminReadRouter({ databasePool, authenticateAdmin = null }) {
  const router = express.Router();
  router.use(requestIdMiddleware);
  router.use(requireAdminAuthentication(authenticateAdmin));

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
