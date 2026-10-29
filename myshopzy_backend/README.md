# MyShopzy Backend

CommonJS/Express backend for the MyShopzy Mandapeta delivery platform.
Customer catalog read APIs are implemented against PostgreSQL. Catalog reads
are public; customer account, parcel, order-history, and saved-address APIs
require a verified customer session. Customer OTP/login routes are not mounted.
Cart and checkout use customer-owned carts and require the same verified
customer session. Admin, partner, and rider endpoints retain their separate
access controls. The backend is not production-ready.

## Structure

- `src/app.js` creates the Express application and exposes `GET /health`.
- `src/modules/catalog/routes.js` implements public shop, category, and product
  catalog reads under `/api/v1`.
- `GET /api/v1/partner-categories` returns active partner types and counts for
  the customer Home Page.
- `src/modules/cart-checkout/routes.js` protects cart and checkout endpoints;
  it also creates prepaid Razorpay orders and verifies customer payment
  callbacks.
- `src/modules/customer-account/routes.js` implements authenticated,
  customer-scoped `/me/*` endpoints, including parcel and address APIs.
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

Cart and checkout endpoints (`/api/v1/carts`, `/api/v1/cart`,
`/api/v1/cart/items`, `/api/v1/checkout/quote`, and `/api/v1/orders`) require a
verified customer session. Cart tokens are additionally bound to the
authenticated customer in migration 018; a token alone is not proof of
identity. `POST /api/v1/orders` calculates totals from database state and
accepts `paymentMethod: "cod"` or `"prepaid"`. Prepaid requests also require a
client-generated `checkoutRequestId` UUID for idempotent retries. The backend
creates a pending MyShopzy order and Razorpay order using the server-calculated
amount, then returns only the public TEST MODE Key ID, Razorpay order ID,
amount, and currency. `POST /api/v1/orders/:orderId/verify-payment` checks the
Razorpay signature and confirms the provider reports a captured payment before
marking the payment attempt verified and changing the order to `placed`.
Unpaid orders remain `payment_pending` and are excluded from partner order
views and rider offers. Repeating the same prepaid request ID reuses its order
and payment attempt.

Delivery pricing uses integer paise and integer metres. Standard orders use a
4,000-metre base distance and 4,000-paise base fee; parcel bookings use a
2,000-metre base distance and 2,500-paise base fee. Both add one paisa per
metre beyond the base distance. The road route is pickup-to-drop only.
Checkout addresses and parcel pickup/drop requests must include coordinates
within India's configured bounding box. A missing route or provider failure
returns `503 DISTANCE_UNAVAILABLE`; no straight-line or client-supplied
distance/fee fallback is used.

Configure routing on the backend only with `ROUTING_PROVIDER=google` and
`ROUTING_API_KEY=<server-side Google Routes API key>`. The `fake` provider is
available for tests and local development only; production startup rejects it.
For Razorpay testing, set `RAZORPAY_KEY_ID` to a `rzp_test_` key ID and
`RAZORPAY_KEY_SECRET` to its matching secret in the backend `.env` file. Keep
both values server-side; only the Key ID is returned to the customer checkout.
The backend rejects live-mode Key IDs. Never put either setting in Flutter
build defines, assets, logs, or API responses.
The Flutter web app's development origin is allowed by default only in
development mode (`http://127.0.0.1:7357`). Set `CUSTOMER_APP_ORIGINS` to a
comma-separated list of exact HTTPS origins for deployed customer web apps;
wildcards are rejected.
Existing shop coordinates are copied from their address JSON when possible;
shops without coordinates must be updated before they can be quoted or
ordered. No database migrations are run as part of this change. Server-side
pricing uses database state and backend route distance; clients cannot provide
trusted prices or fees.

The Express JSON body parser rejects request bodies larger than 16 KB. The
PostgreSQL pool bounds connection wait time to prevent requests and readiness
checks from hanging indefinitely during database outages.

The customer OTP and development-customer authentication routers are not
mounted. Customer-private routes return `401 AUTHENTICATION_REQUIRED` without
a verified customer session and derive ownership from that session; they do not
accept a customer ID from the request. The account routes include:

- `GET /api/v1/me/profile`, `PATCH /api/v1/me/profile`
- `GET /api/v1/me/addresses`, `POST /api/v1/me/addresses`,
  `PATCH /api/v1/me/addresses/:addressId`,
  `DELETE /api/v1/me/addresses/:addressId`
- `GET /api/v1/me/wishlist`, `POST /api/v1/me/wishlist/items`,
  `DELETE /api/v1/me/wishlist/items/:productId`
- `GET /api/v1/me/orders`, `GET /api/v1/me/orders/:orderId`
- `GET /api/v1/me/dues`, `POST /api/v1/me/dues/:entryId/dispute`
- `POST /api/v1/me/parcels`, `GET /api/v1/me/parcels`,
  `GET /api/v1/me/parcels/:parcelId`

- `POST /api/v1/me/parcels` creates a parcel booking owned by the authenticated
  customer. `GET /api/v1/me/parcels` and
  `GET /api/v1/me/parcels/:parcelId` read only that customer's bookings.

Migrations 002–004 add cart, customer-account, dynamic partner-category, and
serviceability storage. Migration 012 adds COD/prepaid order payment method,
delivery-failure records, and an append-only customer dues ledger. Pending
failed-delivery dues do not block checkout; an admin must confirm them before
they count toward the balance. Customer disputes append notes without changing
the balance. Address, wishlist, profile, order, parcel, and dues endpoints are
customer-scoped and never accept a customer ID in their request body.

Rider API endpoints:

- `GET /api/v1/rider/orders/available` lists unassigned `packed` orders
  within 5 km of the rider's fresh location, only while online, within the
  server-enforced 7:00 AM–10:00 PM Asia/Kolkata duty window, and below the
  active-order limit. Offers do not include the customer's address or phone.
- `POST /api/v1/rider/orders/:orderId/accept` atomically assigns an available
  order only while the rider is online, within duty hours, and below the
  active-order limit; accepted orders then return delivery and contact details.
- `PATCH /api/v1/rider/orders/:orderId/cancel` accepts a required reason and
  returns an order to the available pool only before pickup.
- `PATCH /api/v1/rider/orders/:orderId/status` accepts `picked_up`,
  `out_for_delivery`, or `delivered` in that order, and only updates orders
  assigned to that rider. Replaying the current stage is safe for client retry
  queues; delivery completion writes the rider settlement idempotently.
- `PATCH /api/v1/rider/orders/:orderId/arrived` marks the assigned rider's
  arrival once while the order is out for delivery. The rider response includes
  the server-recorded arrival time, support availability time, and support
  phone. A customer-fault delivery failure is rejected until that support
  waiting period has elapsed.
- `PATCH /api/v1/rider/orders/:orderId/delivery-failed` records a permitted
  customer-fault reason and the rider's last known coordinates only after the
  support waiting period. A COD order creates a pending-review due using its
  server-stored total; prepaid orders never create dues.
- `POST /api/v1/rider/location` accepts latitude, longitude, accuracy, and an
  accuracy in metres plus an ISO-8601 `capturedAt`; the server compares it to
  server time and rejects fixes older than 60 seconds. A fix older than two
  minutes is stale and prevents offers until a fresh fix is received.
- `PATCH /api/v1/rider/availability` accepts `{ "isOnline": false }` to go off
  duty; going online requires the fresh location fields accepted by the
  location endpoint. Active deliveries keep the rider online after closing.
- `GET /api/v1/rider/earnings/summary` returns the rider's daily and lifetime
  completed-delivery settlement totals in minor currency units.

In non-production environments, `X-Rider-Id` selects the rider; when omitted,
the API uses `00000000-0000-4000-8000-000000000001`. Apply the migrations and
`database/seed.sql` to create that sample rider. The mock header authenticator
is disabled in production; production deployments must inject a trusted
`authenticateRider` middleware that sets `req.auth.riderUserId`.
`RIDER_OFFER_RADIUS_M` and `RIDER_MAX_ACTIVE_ORDERS` are backend settings,
defaulting to 5000 metres and 2 active orders. Apply migration
`017_rider_support_escalations.sql` after the earlier migrations before
deploying support escalation routes. `SUPPORT_PHONE` defaults to
`+91 88972 67490`; `SUPPORT_ESCALATION_MINUTES` defaults to 10.

Prepared Super Admin queries cover orders, customers, partners, products, and
dues. Dues can be confirmed with a support reference, waived with a reason, and
cleared with a referenced payment; each action appends a ledger row. Admin
routes mount only when `AUTH0_ISSUER_URL`, `AUTH0_AUDIENCE`,
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

Admin dues routes use the existing Auth0 admin authentication:

- `GET /api/v1/admin/dues?status=pending_review&limit=20&offset=0`
- `POST /api/v1/admin/dues/:entryId/confirm` requires
  `{ "supportReference": "SUP-123", "note": "Optional" }`.
- `POST /api/v1/admin/dues/:entryId/waive` requires
  `{ "reason": "..." }`.
- `POST /api/v1/admin/customers/:customerId/dues/payments` requires
  `{ "amount": 500, "reference": "receipt-123" }`, where `amount` is integer
  paise. Payments above the outstanding balance are rejected.

Support escalation routes use the same admin authentication:

- `GET /api/v1/admin/support/escalations?limit=20&offset=0` lists orders
  waiting beyond the configured support window and marks their first
  escalation time on read.
- `POST /api/v1/admin/support/escalations/:orderId/resolve` requires
  `{ "supportReference": "SUP-123", "outcome": "customer_unreachable",
  "note": "Optional" }`. `customer_reached` clears the escalation; the two
  customer-fault outcomes create one pending due for a COD order, based only on
  the order total.

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

Customer OTP authentication modules remain in the codebase, but the running
server does not mount them. Until the final authentication phase supplies a
valid customer session, private customer operations fail closed. Admin,
partner, and rider APIs keep their existing independent authentication and
authorization checks.

Role-based authorization and general request logging are not implemented for
all planned areas. Catalog endpoints validate query/path inputs and return
generic errors without leaking PostgreSQL details. The PostgreSQL pool uses
validated environment settings; pool errors and readiness responses do not
expose database diagnostics or credentials. Payment processing, object
storage, and production deployment remain unconfigured. Razorpay is restricted
to TEST MODE; live payments are not supported.

The migrations do not model coupons, refunds, reviews, general support
ticketing, or notifications. Coupon eligibility/redemption, notification
delivery, support ticketing, and review/rating records need separately designed
schema and integrations before those APIs can be implemented.
