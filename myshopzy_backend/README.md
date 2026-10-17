# MyShopzy Backend

CommonJS/Express backend for the MyShopzy Mandapeta delivery platform.
Customer catalog read APIs are implemented against the initial PostgreSQL
schema. Customer profile, saved-address, cart, checkout, serviceability, and
order APIs are backed by PostgreSQL. Order placement and customer-specific
routes require trusted customer authentication. The only configured customer
authentication is an explicitly development-only OTP path. The backend is not
production-ready.

## Structure

- `src/app.js` creates the Express application and exposes `GET /health`.
- `src/modules/catalog/routes.js` implements public shop, category, and product
  catalog reads under `/api/v1`.
- `GET /api/v1/partner-categories` returns active partner types and counts for
  the customer Home Page.
- `src/modules/cart-checkout/routes.js` implements anonymous capability-token
  carts, server-priced checkout quotes, and authenticated order placement.
- `src/modules/riders/routes.js` implements rider order offers, order acceptance
  and status updates, and live location pings.
- `src/server.js` loads environment variables and starts the HTTP server.
- `src/config/env.js` validates the HTTP port and any PostgreSQL environment
  configuration. `src/config/database.js` creates the PostgreSQL pool and
  provides a `SELECT 1` readiness check when database settings are supplied.
- `src/middleware/`, `src/routes/`, `src/validators/`, and `src/utils/` are
  reserved for shared API infrastructure.
- `src/modules/` contains one folder for each planned business area: `auth`,
  `users`, `addresses`, `partners`, `shops`, `catalog`, `products`,
  `categories`, `cart`, `orders`, `riders`, `deliveries`, `tracking`,
  `payments`, `refunds`, `notifications`, `commissions`, `settlements`,
  `admin`, and `audit`.
- `database/migrations/` contains reviewed, versioned SQL migrations.
- `database/seed.sql` provides sample catalog rows and a demo rider used by the
  development-only rider mock authentication.
- `tests/unit/` and `tests/integration/` are reserved for future tests.
- `docs/` is reserved for API and implementation documentation.

`GET /health` reports process liveness. `GET /health/ready` reports database
readiness with a generic response and returns HTTP 503 when PostgreSQL is
unconfigured or unavailable. Customer API request/response mapping and schema
gaps are documented in `docs/customer-api-mapping.md`.

Implemented customer catalog endpoints:

- `GET /api/v1/partner-categories`
- `GET /api/v1/shops`
- `GET /api/v1/shops/:shopId/categories`
- `GET /api/v1/products`
- `GET /api/v1/products/:productId`
- `POST /api/v1/delivery/serviceability`

Catalog endpoints require PostgreSQL and only return active shops/products
belonging to approved partners. They do not expose customer-specific records.
Do not accept a client-supplied customer ID as authorization.

Product presentation metadata can be stored in the product `attributes` JSON and
is returned by the catalog endpoints. The Flutter catalog recognizes `image_url`,
`rating` (0-5), `mrp_minor`, `discount_percent`, `badge`, `brand`, and
`pack_size`. Produce listings additionally require `produce_type` set to `fruit`
or `vegetable`; this keeps unrelated grocery products out of the produce views.
Prices and MRP values use the product currency's minor units.

The partner-category endpoint reads distinct active partner types and counts
from `app.partners`. Migration 004 provides the `is_active` projection over the
existing approval status and permits new normalized partner-type identifiers.
New types such as `bakery` or `sweet_shop` appear without a Flutter or backend
code change.

The serviceability endpoint validates coordinates and checks the submitted
pincode against `app.serviceable_pincodes`. The table is empty until delivery
areas are configured, so delivery fails closed. Order placement repeats the
pincode lookup within the order transaction so clients cannot bypass
checkout's serviceability check. This policy is pincode-only and does not
verify that coordinates fall inside a delivery polygon.
Configure an approved delivery pincode with:

```sql
INSERT INTO app.serviceable_pincodes (pincode)
VALUES ('533308')
ON CONFLICT (pincode) DO UPDATE
SET is_active = true, updated_at = now();
```

Cart and checkout endpoints:

- `POST /api/v1/carts` creates a cart and returns a random bearer capability
  token once. Send it in `X-Cart-Token`; only its SHA-256 hash is persisted.
- `GET /api/v1/cart` retrieves that token's cart.
- `POST /api/v1/cart/items` adds `{ "productId": "...", "quantity": 1 }`.
- `PATCH /api/v1/cart/items/:productId` sets a positive quantity.
- `DELETE /api/v1/cart/items/:productId` removes an item.
- `DELETE /api/v1/cart/items` clears the cart.
- `POST /api/v1/checkout/quote` calculates a quote from current PostgreSQL
  product prices; delivery and discount are currently zero because pricing
  rules and coupons are not modeled.
- `POST /api/v1/orders` accepts `{ "deliveryAddress": { ... } }`, creates the
  order and immutable item snapshots in one transaction, and decrements
  tracked inventory in that same transaction.

Cart tokens are bearer secrets for anonymous carts, not customer identities.
Anyone with a token can operate that cart; clients must protect it like a
credential. Configured Flutter catalog products, cart operations, checkout
quotes, and order placement use these APIs. Order placement is disabled unless
`createApp` receives a trusted `authenticateCustomer` middleware which sets
`req.auth.customerUserId` from verified authentication. The running server
injects the development-only customer authenticator described below. Request
bodies cannot choose the customer, and private customer APIs remain protected
by verified bearer-token authentication.

The Express JSON body parser rejects request bodies larger than 16 KB. The
PostgreSQL pool bounds connection wait time to prevent requests and readiness
checks from hanging indefinitely during database outages.

Authenticated customer API foundations (all return `401` unless a trusted
`authenticateCustomer` middleware is injected):

- `GET /api/v1/me/profile`, `PATCH /api/v1/me/profile`
- `GET /api/v1/me/addresses`, `POST /api/v1/me/addresses`,
  `PATCH /api/v1/me/addresses/:addressId`,
  `DELETE /api/v1/me/addresses/:addressId`
- `GET /api/v1/me/wishlist`, `POST /api/v1/me/wishlist/items`,
  `DELETE /api/v1/me/wishlist/items/:productId`
- `GET /api/v1/me/orders`, `GET /api/v1/me/orders/:orderId`
- `POST /api/v1/me/parcels`, `GET /api/v1/me/parcels`,
  `GET /api/v1/me/parcels/:parcelId`

Migrations 002–004 add cart, customer-account, dynamic partner-category, and
serviceability storage. Address, wishlist, profile, order, and parcel endpoints
are customer-scoped and never accept a customer ID in their route or request
body. Order history/details are read only.

Rider API endpoints:

- `GET /api/v1/rider/orders/available` lists unassigned `getting_packed` orders
  with their shop and delivery details only while the requesting rider is
  online; offline riders receive `403 RIDER_OFFLINE`.
- `POST /api/v1/rider/orders/:orderId/accept` atomically assigns an available
  order only while the rider is online, then returns assigned delivery,
  coordinates, and customer/shop contact details.
- `PATCH /api/v1/rider/orders/:orderId/status` accepts `picked_up`,
  `out_for_delivery`, or `delivered` in that order, and only updates orders
  assigned to that rider. Replaying the current stage is safe for client retry
  queues; delivery completion writes the rider settlement idempotently.
- `POST /api/v1/rider/location` accepts `{ "latitude": 16.87, "longitude": 81.93 }`
  and stores the coordinates while marking the rider online.
- `PATCH /api/v1/rider/availability` accepts `{ "isOnline": false }` to go off
  duty; going online requires a valid location ping.
- `GET /api/v1/rider/earnings/summary` returns the rider's daily and lifetime
  completed-delivery settlement totals in minor currency units.

In non-production environments, `X-Rider-Id` selects the rider; when omitted,
the API uses `00000000-0000-4000-8000-000000000001`. Apply the migrations and
`database/seed.sql` to create that sample rider. The mock header authenticator
is disabled in production; production deployments must inject a trusted
`authenticateRider` middleware that sets `req.auth.riderUserId`.

Prepared Super Admin read-only queries cover orders, customers, partners, and
products. Admin routes mount only when `AUTH0_ISSUER_URL`, `AUTH0_AUDIENCE`,
`AUTH0_ADMIN_USER_ID_CLAIM`, `SUPER_ADMIN_ORIGIN`, and PostgreSQL are
configured. The Auth0 access token is
verified against the issuer's remote JWKS, RS256 signature, issuer, audience,
expiry, and not-before claims. The configured namespaced
`AUTH0_ADMIN_USER_ID_CLAIM` must carry a manually provisioned
`app_metadata` mapping to an existing database user UUID. An approved Auth0
Post-Login Action must set this claim from that managed metadata; users must
not be able to edit the mapping. Backend authorization still checks the mapped
database record's role and active status on every request. The origin setting permits only the
configured frontend origin for browser requests. Keep these settings unset
until the Auth0 application/API, claim namespace, and manual identity mappings
have been configured and reviewed.

## Setup and run

Requires Node.js 18.11 or later.

1. Install the project dependencies locally:

   ```sh
   npm install
   ```

2. Copy `.env.example` to `.env` and set local environment values. Do not commit
   `.env` or put real credentials in source control.

3. Start the development server:

   ```sh
   npm run dev
   ```

   Or start it without watch mode:

   ```sh
   npm start
   ```

4. Check `http://localhost:3000/health`.

Run the test script with `npm test`.

## Database migrations

The initial multi-partner schema and additive customer schemas are in
`database/migrations/001_initial_multi_partner_schema.sql`,
`database/migrations/002_customer_carts.sql`, and
`database/migrations/003_customer_account_parcels.sql`. They have not been applied.
After reviewing the SQL and verifying the local target configuration,
the command to apply pending migrations is:

```sh
npm run migrate
```

The runner takes a PostgreSQL advisory lock, applies each migration in a
transaction, and records its SHA-256 checksum in
`public.schema_migrations`. It skips a matching applied migration and refuses
to continue if an already-applied migration's contents have changed.

Partner-owned data carries both `partner_id` and `shop_id`, with composite
foreign keys preventing records from mixing shops and partners. Once
authentication is implemented, every partner API must derive the effective
partner scope from the authenticated user's active `partner_memberships` row
and allowed role. A request-supplied partner ID is only a requested selector;
it is never authorization. Customer order access must independently require
the authenticated customer ID to match `orders.customer_user_id`.

Row-level security is not enabled in the initial migration. The backend does
not yet have authenticated request identity or a trusted per-request database
context, so partner-owned rows are not protected by a database tenant boundary.
Do not expose these tables through partner APIs until application authorization
is in place. The safe RLS follow-up is to add transaction-scoped identity
context established only from verified authentication and active membership,
apply default-deny policies, use a separate application database role that
does not own the tables or have `BYPASSRLS`, and verify isolation with
database-backed tests using that exact role.

## Planned security and integrations

Production authentication, role-based authorization, rate limiting, and request
logging are not implemented yet. Catalog endpoints validate their query/path inputs
and return generic errors without leaking PostgreSQL details.
The PostgreSQL pool uses the validated environment settings. Pool errors and
readiness responses do not expose database error details or credentials.
Payment processing, OTP delivery, object storage, and production deployment
remain unconfigured. For local development only, `POST
/api/v1/auth/development/verify-otp` accepts a six-digit code configured through
`DEVELOPMENT_CUSTOMER_OTP` and signs a 15-minute customer bearer token using
`DEVELOPMENT_CUSTOMER_SESSION_SECRET` (at least 32 bytes). No SMS or WhatsApp is
sent. The code is shared development configuration, not real identity
verification; only an existing active customer whose phone matches can receive
a session. The endpoint returns 404 in production, and customer authentication
fails closed there. The Flutter app exposes this flow only in debug builds and
keeps the token in memory; it is lost when the app restarts. Do not use this
mechanism in production or treat it as provider-backed OTP authentication.
The migrations do not model coupons, refunds, reviews,
support requests, notifications, or payment verification. Coupon
eligibility/redemption, notification delivery, support ticketing, payment
verification/provider references, and review/rating records need separately
designed schema and integrations before those APIs can be implemented. Order
creation is available only when a trusted authentication middleware is
injected; production login/signup and provider-backed OTP/JWT authentication
are not implemented.
