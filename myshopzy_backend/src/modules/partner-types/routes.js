const { randomUUID } = require('node:crypto');
const express = require('express');
const { getPartnerTypeProfile } = require('./profiles');
const { createPartnerProductOrderRouter } = require('./products-orders-routes');

const REQUEST_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$/;

function requestIdMiddleware(req, res, next) {
  const suppliedRequestId = req.get('x-request-id');
  req.requestId = suppliedRequestId && REQUEST_ID_PATTERN.test(suppliedRequestId)
    ? suppliedRequestId
    : randomUUID();
  res.set('X-Request-ID', req.requestId);
  next();
}

function requirePartnerAuthentication(authenticatePartner) {
  return (req, res, next) => {
    if (typeof authenticatePartner !== 'function') {
      return res.status(401).json({
        error: {
          code: 'AUTHENTICATION_REQUIRED',
          message: 'Partner authentication is required.',
        },
        meta: { requestId: req.requestId },
      });
    }
    try {
      const result = authenticatePartner(req, res, (error) => {
        if (error) return next(error);
        if (res.headersSent) return;
        if (
          !req.partnerContext ||
          typeof req.partnerContext.userId !== 'string' ||
          typeof req.partnerContext.partnerId !== 'string'
        ) {
          return res.status(403).json({
            error: {
              code: 'PARTNER_CONTEXT_REQUIRED',
              message: 'An active partner context is required.',
            },
            meta: { requestId: req.requestId },
          });
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

function createPartnerRouter({ databasePool, authenticatePartner = null }) {
  const router = express.Router();
  router.use(requestIdMiddleware);
  router.use(requirePartnerAuthentication(authenticatePartner));
  router.use(createPartnerProductOrderRouter({ databasePool }));

  router.get('/partner/me/config', async (req, res, next) => {
    if (!databasePool) {
      return res.status(503).json({
        error: {
          code: 'DATABASE_UNAVAILABLE',
          message: 'Partner configuration is temporarily unavailable.',
        },
        meta: { requestId: req.requestId },
      });
    }

    try {
      const partnerResult = await databasePool.query(
        `SELECT
           id,
           name,
           partner_type,
           status,
           contact_email,
           contact_phone,
           timezone
         FROM app.partners
         WHERE id = $1::uuid
         LIMIT 1`,
        [req.partnerContext.partnerId],
      );
      if (partnerResult.rows.length !== 1) {
        return res.status(404).json({
          error: {
            code: 'PARTNER_NOT_FOUND',
            message: 'The authenticated partner could not be found.',
          },
          meta: { requestId: req.requestId },
        });
      }

      const partner = partnerResult.rows[0];
      const profile = getPartnerTypeProfile(partner.partner_type);
      if (!profile) {
        return res.status(403).json({
          error: {
            code: 'PARTNER_TYPE_UNSUPPORTED',
            message: 'This partner type is not supported.',
          },
          meta: { requestId: req.requestId },
        });
      }

      const shopsResult = await databasePool.query(
        `SELECT id, name, slug, status, address, operating_details
         FROM app.shops
         WHERE partner_id = $1::uuid
         ORDER BY created_at, id`,
        [req.partnerContext.partnerId],
      );

      return res.status(200).json({
        data: {
          profile,
          partner: {
            id: partner.id,
            name: partner.name,
            type: partner.partner_type,
            status: partner.status,
            contactEmail: partner.contact_email,
            contactPhone: partner.contact_phone,
            timezone: partner.timezone,
          },
          shops: shopsResult.rows.map((shop) => ({
            id: shop.id,
            name: shop.name,
            slug: shop.slug,
            status: shop.status,
            address: shop.address,
            operatingDetails: shop.operating_details,
          })),
        },
        meta: { requestId: req.requestId },
      });
    } catch (error) {
      return next(error);
    }
  });

  return router;
}

module.exports = { createPartnerRouter };
