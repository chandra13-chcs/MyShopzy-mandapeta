# MyShopzy Backend

Initial CommonJS/Express backend skeleton for the MyShopzy Mandapeta delivery
platform. This is not production-ready and does not connect to PostgreSQL or
implement business APIs.

## Structure

- `src/app.js` creates the Express application and exposes `GET /health`.
- `src/server.js` loads environment variables and starts the HTTP server.
- `src/config/env.js` validates the HTTP port and any PostgreSQL environment
  configuration. `src/config/database.js` creates the PostgreSQL pool and
  provides a `SELECT 1` readiness check when database settings are supplied.
- `src/middleware/`, `src/routes/`, `src/validators/`, and `src/utils/` are
  reserved for shared API infrastructure.
- `src/modules/` contains one folder for each planned business area: `auth`,
  `users`, `addresses`, `partners`, `shops`, `products`, `categories`, `cart`,
  `orders`, `riders`, `deliveries`, `tracking`, `payments`, `refunds`,
  `notifications`, `commissions`, `settlements`, `admin`, and `audit`.
- `database/migrations/` contains reviewed, versioned SQL migrations.
- `database/seeds/` remains reserved; no seed data is included.
- `tests/unit/` and `tests/integration/` are reserved for future tests.
- `docs/` is reserved for API and implementation documentation.

Future business APIs will use the `/api/v1` prefix. `GET /health` reports process liveness. `GET /health/ready` reports database
readiness with a generic response and returns HTTP 503 when PostgreSQL is
unconfigured or unavailable.

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

Run the test script with `npm test`. There are no business APIs yet.

## Database migrations

The initial multi-partner schema is in
`database/migrations/001_initial_multi_partner_schema.sql`. It has not been
applied. After reviewing the SQL and verifying the local target configuration,
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

Input validation, centralized error handling, authentication, role-based
authorization, rate limiting, and request logging are not implemented yet.
The PostgreSQL pool uses the validated environment settings. Pool errors and
readiness responses do not expose database error details or credentials.
Payment processing, OTP delivery, object storage, and production deployment
remain unconfigured.
