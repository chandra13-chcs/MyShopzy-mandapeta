const express = require('express');
const { isDatabaseReady } = require('./config/database');
const { createCatalogRouter } = require('./modules/catalog/routes');
const { createCartCheckoutRouter } = require('./modules/cart-checkout/routes');
const { createCustomerAccountRouter } = require('./modules/customer-account/routes');
const { createAdminReadRouter } = require('./modules/admin-read/routes');

function createApp({
  databasePool = null,
  authenticateCustomer = null,
  authenticateAdmin = null,
  superAdminOrigin = null,
  developmentCustomerAuthRouter = null,
} = {}) {
  const app = express();

  app.use(express.json());

  app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok' });
  });

  app.get('/health/ready', async (req, res) => {
    const ready = await isDatabaseReady(databasePool);
    res.status(ready ? 200 : 503).json({
      status: ready ? 'ready' : 'not_ready',
    });
  });

  if (developmentCustomerAuthRouter) {
    app.use('/api/v1', developmentCustomerAuthRouter);
  }
  app.use('/api/v1', createCatalogRouter({ databasePool }));
  app.use(
    '/api/v1',
    createCartCheckoutRouter({ databasePool, authenticateCustomer }),
  );
  app.use(
    '/api/v1',
    createCustomerAccountRouter({ databasePool, authenticateCustomer }),
  );
  if (typeof authenticateAdmin === 'function') {
    if (superAdminOrigin) {
      app.use('/api/v1/admin', (req, res, next) => {
        if (req.get('origin') !== superAdminOrigin) return next();
        res.set('Access-Control-Allow-Origin', superAdminOrigin);
        res.vary('Origin');
        if (req.method === 'OPTIONS') {
          res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
          res.set(
            'Access-Control-Allow-Headers',
            'Authorization, Content-Type, X-Request-ID',
          );
          return res.status(204).end();
        }
        return next();
      });
    }
    app.use(
      '/api/v1',
      createAdminReadRouter({ databasePool, authenticateAdmin }),
    );
  }

  app.use('/api/v1', (req, res) => {
    res.status(404).json({
      error: { code: 'NOT_FOUND', message: 'API endpoint not found.' },
    });
  });

  app.use((error, req, res, next) => {
    if (res.headersSent) {
      next(error);
      return;
    }

    if (error instanceof SyntaxError && error.status === 400 && 'body' in error) {
      res.status(400).json({
        error: { code: 'INVALID_REQUEST', message: 'Request body must be valid JSON.' },
      });
      return;
    }

    res.status(500).json({
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'An unexpected error occurred.',
      },
    });
  });

  return app;
}

module.exports = createApp();
module.exports.createApp = createApp;
