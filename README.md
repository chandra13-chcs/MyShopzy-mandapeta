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
customer catalog and cart APIs, provide the backend origin when starting the
app (do not include `/api/v1`):

```sh
flutter run --dart-define=MYSHOPZY_API_BASE_URL=http://localhost:3000
```

Use a host address reachable from the target device or emulator in place of
`localhost` when needed; non-loopback backend URLs must use HTTPS. Restaurant
and grocery/local-store shops, their
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
