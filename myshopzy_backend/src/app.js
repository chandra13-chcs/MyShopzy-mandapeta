const express = require('express');
const { isDatabaseReady } = require('./config/database');
const { createCatalogRouter } = require('./modules/catalog/routes');
const { createCartCheckoutRouter } = require('./modules/cart-checkout/routes');
const { createCustomerAccountRouter } = require('./modules/customer-account/routes');
const { createAdminReadRouter } = require('./modules/admin-read/routes');
const { createPartnerRouter } = require('./modules/partner-types/routes');
const {
  createDeliveryServiceabilityRouter,
} = require('./modules/delivery-serviceability/routes');
const { createRiderRouter } = require('./modules/riders/routes');
const { mockRiderAuth } = require('./middleware/mock-rider-auth');

function createApp({
  databasePool = null,
  authenticateCustomer = null,
  deliveryRoutingClient = null,
  deliveryDistanceClient = null,
  razorpayClient = null,
  razorpayKeyId = null,
  razorpayKeySecret = null,
  authenticateRider = null,
  canAcceptOrders = () => true,
  applyRiderCancelPenalty = async () => {},
  supportPhone = '+91 88972 67490',
  supportEscalationMinutes = 10,
  authenticateAdmin = null,
  authenticatePartner = null,
  superAdminOrigin = null,
  partnerPortalOrigins = ['http://localhost:5173'],
  customerAppOrigins = ['http://127.0.0.1:7357'],
  now = () => new Date(),
  nodeEnv = 'development',
  logger = console,
} = {}) {
  const app = express();
  const configuredDistanceClient =
    deliveryDistanceClient ??
    (deliveryRoutingClient
      ? {
          getRoadDistanceMetres(origin, destination) {
            return deliveryRoutingClient.getDrivingDistanceMeters({
              origin,
              destination,
            });
          },
        }
      : null);

  app.use(express.json({ limit: '16kb' }));

  app.get('/', (req, res) => {
    res.status(200).json({
      service: 'MyShopzy API',
      status: 'ok',
      health: '/health',
      apiBase: '/api/v1',
    });
  });

  app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok' });
  });

  app.get('/health/ready', async (req, res) => {
    const ready = await isDatabaseReady(databasePool);
    res.status(ready ? 200 : 503).json({
      status: ready ? 'ready' : 'not_ready',
    });
  });

  app.use('/api/v1', (req, res, next) => {
    const origin = req.get('origin');
    if (!origin || !customerAppOrigins.includes(origin)) return next();
    res.set('Access-Control-Allow-Origin', origin);
    res.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS');
    res.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type, X-Cart-Token, X-Request-ID',
    );
    res.vary('Origin');
    if (req.method === 'OPTIONS') return res.status(204).end();
    return next();
  });

  app.get('/api/v1', (req, res) => {
    res.status(200).json({
      service: 'MyShopzy API',
      version: 'v1',
      status: 'ok',
      endpoints: {
        partnerCategories: '/api/v1/partner-categories',
        shops: '/api/v1/shops',
        shopCategories: '/api/v1/shops/:shopId/categories',
        products: '/api/v1/products',
        productDetails: '/api/v1/products/:productId',
      },
    });
  });

  app.use(
    '/api/v1',
    createDeliveryServiceabilityRouter({ databasePool }),
  );
  app.use(
    '/api/v1',
    createRiderRouter({
      databasePool,
      now,
      canAcceptOrders,
      applyRiderCancelPenalty,
      supportPhone,
      supportEscalationMinutes,
      authenticateRider:
        authenticateRider ??
        (nodeEnv === 'production' ? null : mockRiderAuth),
    }),
  );
  app.use('/api/v1', createCatalogRouter({ databasePool, now }));
  app.use(
    '/api/v1',
    createCartCheckoutRouter({
      databasePool,
      authenticateCustomer,
      deliveryDistanceClient: configuredDistanceClient,
      razorpayClient,
      razorpayKeyId,
      razorpayKeySecret,
    }),
  );
  app.use(
    '/api/v1',
    createCustomerAccountRouter({
      databasePool,
      authenticateCustomer,
      deliveryDistanceClient: configuredDistanceClient,
    }),
  );
  app.use('/api/v1/partner', (req, res, next) => {
    const origin = req.get('origin');
    if (origin && partnerPortalOrigins.includes(origin)) {
      res.set('Access-Control-Allow-Origin', origin);
      res.set('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
      res.set(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type, X-Request-ID',
      );
      res.vary('Origin');
      if (req.method === 'OPTIONS') return res.status(204).end();
    }
    return next();
  });
  app.use(
    '/api/v1',
    createPartnerRouter({ databasePool, authenticatePartner }),
  );
  if (typeof authenticateAdmin === 'function') {
    if (superAdminOrigin) {
      app.use('/api/v1/admin', (req, res, next) => {
        if (req.get('origin') !== superAdminOrigin) return next();
        res.set('Access-Control-Allow-Origin', superAdminOrigin);
        res.vary('Origin');
        if (req.method === 'OPTIONS') {
          res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
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
      createAdminReadRouter({
        databasePool,
        authenticateAdmin,
        supportEscalationMinutes,
      }),
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

    if (error?.type === 'entity.too.large') {
      res.status(413).json({
        error: {
          code: 'REQUEST_TOO_LARGE',
          message: 'Request body must not exceed 16 KB.',
        },
      });
      return;
    }

    logger.error('Unhandled API error.', {
      method: req.method,
      errorName: error?.name ?? 'Error',
    });
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
