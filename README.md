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

## Backend connection

Public catalog browsing can use the backend by providing its origin when
starting the app (do not include `/api/v1`). The backend listens on port `3000`
by default (`PORT` can override it):

```sh
flutter run --dart-define=MYSHOPZY_API_BASE_URL=http://localhost:3000
```

Use an origin reachable from the target:

- Chrome/web on the development machine: `http://localhost:3000`.
- Android emulator or USB-connected Android device: run
  `adb reverse tcp:3000 tcp:3000`, then use `http://localhost:3000`.
- Physical Android over Wi-Fi: use a development backend origin reachable
  from the device over HTTPS. The app rejects non-loopback HTTP URLs.

The VS Code task **Run MyShopzy in Chrome** supplies the local web development
origin (`http://localhost:3000`). Start the backend separately as described
below; this task does not start or configure the backend.

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
not configured or unavailable. Parcel route checks also require the backend-only
`ROUTING_API_KEY` for Google Routes; the Flutter app must never receive this key.

Restaurant and grocery/local-store shops, their categories and products remain
public catalog reads. If catalog requests fail, the existing demo catalog
remains visible and is labeled as demo data. In debug builds, customer screens
are available as a UI preview without signing in. The preview does not create a
customer session or provide backend data. Cart synchronization, checkout,
order placement, payments, parcel booking/history, order history, and
saved-address requests still require a real customer session and remain
protected by backend authorization. Release builds continue to require
customer authentication to open customer screens. The app does not provide
customer login or OTP yet.

The backend rejects unauthenticated customer API requests. Cart and checkout
also fail closed for authenticated requests until cart ownership can be tied to
the verified customer in the database; cart tokens and device/customer IDs are
not authentication credentials. No database migration is run as part of this
work. See [the backend README](myshopzy_backend/README.md) for route behavior.
