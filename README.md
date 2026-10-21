# myshopzy

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Customer API mode

The app uses the existing demo catalog and cart by default. To use the
customer APIs, provide the backend origin when starting the app (do not include
`/api/v1`). The backend listens on port `3000` by default (`PORT` can override
it):

```sh
flutter run --dart-define=MYSHOPZY_API_BASE_URL=http://localhost:3000
```

Use an origin reachable from the target:

- Chrome/web on the development machine: `http://localhost:3000`.
- Android emulator or USB-connected Android device: run
  `adb reverse tcp:3000 tcp:3000`, then use `http://localhost:3000`.
- Physical Android over Wi-Fi: use a development backend origin reachable
  from the device over HTTPS. The app rejects non-loopback HTTP URLs.

Check backend liveness at `/health`; `/health/ready` additionally checks
PostgreSQL readiness. Start the backend from the repository root with:

```sh
cd myshopzy_backend
npm install
npm run dev
```

Copy `myshopzy_backend/.env.example` to an untracked `.env` and set local
PostgreSQL values before expecting database-backed parcel APIs to work. The
health endpoint can succeed while `/health/ready` reports that PostgreSQL is
not configured or unavailable.

### Development-only OTP login

For local debug login only, the OTP screen can display the configured test OTP
without adding an endpoint that reveals it. Create an untracked
`development.local.json` in the project root (it is ignored by Git):

```json
{
  "MYSHOPZY_API_BASE_URL": "http://localhost:3000",
  "MYSHOPZY_DEVELOPMENT_CUSTOMER_OTP": "your-local-six-digit-test-code"
}
```

Set the OTP value to match `DEVELOPMENT_CUSTOMER_OTP` in the backend's local
environment. Do not put `DEVELOPMENT_CUSTOMER_SESSION_SECRET` or other backend
secrets in this Flutter file. Run the app with:

```sh
flutter run --dart-define-from-file=development.local.json
```

The hint is rendered only in debug builds and only for a valid six-digit value;
release builds never display it. No SMS or WhatsApp message is sent. The
backend remains responsible for verifying the entered OTP and issuing a
customer session. Restaurant and grocery/local-store shops, their
categories and products, cart changes, and checkout quotes then come from the
backend. If catalog requests fail, the existing demo catalog remains visible
and is labeled as demo data. The backend catalog does not currently provide
store ratings, opening hours, delivery estimates, product brands, or reviews;
the app does not present demo values for those fields as backend facts.
Restaurant listing search uses the public shop-name search, and restaurant
menu search uses the public product-name/description search.
Cart mode creates and lists an anonymous capability-token cart, synchronizes
item quantity/removal/clear operations, and uses the backend quote (including
its current line prices) for checkout totals. The token remains in memory only
for the current app session and is sent only in the cart-token request header;
orders still require trusted customer authentication and are not reported as
placed on an authentication error.

### Parcel request API

With a configured API origin and an authenticated customer session, the Parcel
flow submits a request using `POST /api/v1/me/parcels`; request history and
details use `GET /api/v1/me/parcels` and
`GET /api/v1/me/parcels/:parcelId`. These endpoints validate and persist the
pickup/drop text, parcel type, weight (up to 20 kg), and instructions, and
scope reads to the authenticated customer. A successful response is a
`requested` record, not confirmation of an accepted or dispatched delivery.

The customer form supports foreground current-location detection and manual
entry, and can select existing saved addresses. Coordinates and postal codes
are retained in app state when the selected location provides them. The
summary can query the shared serviceability endpoint for both postal areas,
but that endpoint only checks whether each pincode is active; it does not
validate a parcel route, coordinates against a boundary, or the 50 km limit.
This check is informational and does not gate request creation.

The current backend does not define parcel fare rules, a parcel-specific
serviceability/distance check, cancellation policy, rider assignment/tracking,
or a parcel delivery-status workflow. No price is quoted, cancellation or
tracking is offered, and no migration is required for the existing request
API. If a create request times out or loses its connection, the app prevents
another submit during that app session and directs the customer to history;
the backend does not yet provide cross-session idempotency.
