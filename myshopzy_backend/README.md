# MyShopzy Backend

Initial CommonJS/Express backend skeleton for the MyShopzy Mandapeta delivery
platform. This is not production-ready and does not connect to PostgreSQL or
implement business APIs.

## Structure

- `src/app.js` creates the Express application and exposes `GET /health`.
- `src/server.js` loads environment variables and starts the HTTP server.
- `src/config/` is reserved for environment and PostgreSQL configuration.
- `src/middleware/`, `src/routes/`, `src/validators/`, and `src/utils/` are
  reserved for shared API infrastructure.
- `src/modules/` contains one folder for each planned business area: `auth`,
  `users`, `addresses`, `partners`, `shops`, `products`, `categories`, `cart`,
  `orders`, `riders`, `deliveries`, `tracking`, `payments`, `refunds`,
  `notifications`, `commissions`, `settlements`, `admin`, and `audit`.
- `database/migrations/` and `database/seeds/` are reserved; no database
  connection, schema, migration, or seed is included.
- `tests/unit/` and `tests/integration/` are reserved for future tests.
- `docs/` is reserved for API and implementation documentation.

Future business APIs will use the `/api/v1` prefix. The health endpoint is
currently available at `/health`.

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

Run the test script with `npm test`. There are no tests or business APIs yet.

## Planned security and integrations

Input validation, centralized error handling, authentication, role-based
authorization, rate limiting, and request logging are not implemented yet.
PostgreSQL configuration values are placeholders only; the `pg` package is
declared for a future database implementation but is not used to connect.
Payment processing, OTP delivery, object storage, and production deployment
remain unconfigured.
