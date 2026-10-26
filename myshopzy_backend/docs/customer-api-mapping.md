# Customer app API mapping

This mapping follows the current Flutter screens, the existing PostgreSQL
migrations, and the additive customer API migrations.
The server includes separately configured development OTP authentication and
backend-provider-backed customer OTP authentication. Customer creation happens
only after successful OTP verification.
Implemented catalog endpoints are public reads; a customer ID supplied by a
client is not a trusted identity.

## Implemented API contract

All routes use `/api/v1`. Successful list responses have
`{ "data": [...], "pagination": { "limit": 20, "offset": 0 } }`; resource
responses have `{ "data": { ... } }`. Errors have
`{ "error": { "code": "...", "message": "..." } }`.

| Endpoint | Request | Response fields | PostgreSQL tables / behavior |
|---|---|---|---|
| `GET /partner-categories` | No parameters | Distinct `partner_type`, derived `display_name`, active `partner_count` | `app.partners`; `is_active` is generated from the existing approved status |
| `GET /shops` | Optional normalized `partnerType` slug, `q`, `limit` (1–100), `offset` | Shop `id`, `partner_id`, `name`, `slug`, `address`, `operating_details`, `partner_name`, `partner_type` | `app.shops`, `app.partners`; only active shops of approved partners |
| `GET /shops/:shopId/categories` | UUID `shopId` | Category `id`, `shop_id`, `parent_category_id`, `name`, `slug`, `sort_order` | `app.categories`, `app.shops`, `app.partners`; active categories of an active shop and approved partner |
| `GET /products` | Optional UUID `shopId`, UUID `categoryId`, `partnerType`, `q`, `limit` (1–100), `offset` | Product fields plus nullable `image_url`, `thumb_url`, and `variants[]` (`id`, `label`, `unit`, `quantity`, string `price_minor`, nullable `stock`, `is_available`, `sort_order`) | `app.products`, `app.product_variants`, `app.shops`, `app.partners`; variants are aggregated in the product-list query in `sort_order` order |
| `GET /products/:productId` | UUID `productId` | Same product fields and variants as `GET /products` | Same tables and public/available visibility rules |
| `POST /delivery/serviceability` | `{ "latitude": number, "longitude": number, "pincode": "533308" }` | `{ "isDeliverable": boolean, "message": string }` | Validates coordinate ranges and checks `app.serviceable_pincodes`; returns `503 DATABASE_UNAVAILABLE` if PostgreSQL is unavailable |

Variant prices are returned in the database's minor currency unit (`price_minor`,
paise for INR) as strings to preserve bigint precision. The legacy product-level
price and inventory columns remain in catalog responses for compatibility;
cart and checkout calculations use the selected variant's price and stock.
Presentation metadata such as `rating`, `mrp_minor`, `discount_percent`,
`badge`, `brand`, `pack_size`, and `produce_type` may be stored in product
`attributes`; product images use the dedicated `image_url` and `thumb_url`
columns.
All request values are passed separately as PostgreSQL parameters. Invalid
query values return `400`, missing public resources return `404`, unavailable
PostgreSQL returns `503`, and database failures return a generic `500`.
Delivery areas must be configured by inserting approved pincodes into
`app.serviceable_pincodes`; the backend does not expose an unauthenticated
admin write endpoint for service areas.

## Customer account API

Additive migrations 003, 004, and 015 add saved-address, wishlist,
parcel-booking, delivery-serviceability, and server-priced delivery storage. The partner
`is_active` value is generated from approval status; partner type identifiers
use normalized lowercase slugs, so new types do not require code changes.
All customer routes below require a
trusted `authenticateCustomer` middleware which sets
`req.auth.customerUserId`; they return the same `401` response when no trusted
middleware is configured. Client-supplied user IDs are never used as identity.

| Endpoint | Request / result | Tables and scope |
|---|---|---|
| `POST /auth/otp/request` | `{ "phoneNumber": "+919876543210" }`; neutral `202` response with expiry and resend timing | Stores a keyed OTP hash and keyed rate-limit identifiers; sends through the configured backend WhatsApp Authentication template |
| `POST /auth/otp/verify` | `{ "phoneNumber": "+919876543210", "otp": "123456" }`; returns a 15-minute bearer session | `app.customer_otp_challenges`, `app.users`, `app.customers`; creates a customer only after successful verification |
| `GET /me/profile` | Reads display name, email, phone, creation time | `app.users`, `app.customers`; authenticated user only |
| `PATCH /me/profile` | Optional `displayName`, `email`, `phone`; requires at least one of email/phone to remain | `app.users`, `app.customers`; database uniqueness conflicts return `409` |
| `GET /me/addresses` | Lists own saved addresses | `app.customer_saved_addresses` |
| `POST /me/addresses` | `{ "label": "Home", "address": { ... } }` | `app.customer_saved_addresses`; `201` |
| `PATCH /me/addresses/:addressId` | Optional `label`, `address` fields | `app.customer_saved_addresses`; owner-scoped, foreign IDs return `404` |
| `DELETE /me/addresses/:addressId` | UUID path | `app.customer_saved_addresses`; owner-scoped, `204` |
| `GET /me/wishlist` | Lists own saved products with current price and availability | Wishlist, products, shops, partners |
| `POST /me/wishlist/items` | `{ "productId": "<uuid>" }` | Wishlist plus active catalog product; `201` new, `200` existing |
| `DELETE /me/wishlist/items/:productId` | UUID path | Wishlist owner-scoped; `204` |
| `GET /me/orders` | Optional `limit` (1–100), `offset` | Orders, order items, shops; authenticated customer's records only |
| `GET /me/orders/:orderId` | UUID path | Order summary, address snapshot, immutable item snapshots; foreign and missing orders return `404` |
| `GET /me/dues` | No parameters | Authenticated customer's outstanding balance and due summaries, including dispute notes |
| `POST /me/dues/:entryId/dispute` | `{ "message": "..." }` (1–500 characters) | Appends a dispute note to the customer's own pending or confirmed due; does not change its amount or status |
| `POST /me/parcels` | Pickup/drop strings and coordinates, UI parcel type, weight `0 < kg <= 20` (up to three decimal places), optional instructions | `app.parcel_bookings`; recomputes road distance and parcel fee server-side, creates a `requested` booking, `201` |

Customer OTP authentication is not mounted by the running server. Customer
APIs fail closed unless the existing customer-session verifier validates a
signed session. No OTP/login endpoint is available until the final
authentication phase.
| `GET /me/parcels` | Optional `limit` (1–100), `offset` | Authenticated customer's booking list |
| `GET /me/parcels/:parcelId` | UUID path | Owner-scoped booking details; foreign and missing IDs return `404` |

Parcel booking records express a request only. They persist pickup/drop
coordinates, server-calculated distance and fee, but have no dispatch or
completion integration, so the API does not claim that a parcel has been
accepted or delivered.

## Cart, checkout, and order API foundations

The additive migration `002_customer_carts.sql` adds
`app.customer_carts` and `app.customer_cart_items`; migration
`008_product_variants_and_images.sql` adds `variant_id` and changes cart-line
identity to `(cart_id, product_id, variant_id)`. The existing schema stores
only a random token hash and has no customer-owner relation. A token is not
customer authentication, so cart and checkout endpoints currently return 401
without a valid customer session and 503 `CART_OWNERSHIP_UNAVAILABLE` with one.
No schema change or migration is included in this work.

| Endpoint | Request | Response / behavior | PostgreSQL tables |
|---|---|---|---|
| Cart operations | `POST /carts`, `GET /cart`, cart item mutations | Not available until cart records can be tied to the authenticated customer. Cart tokens are never accepted as identity. | Existing cart tables lack customer ownership |
| Checkout quote and order placement | `POST /checkout/quote`, `POST /orders` | Not available until customer-owned cart support is implemented. Authenticated requests fail closed rather than quote or place an order. | Cart tables, orders, and related catalog data |

Order placement checks that every product, shop, and partner is active/approved,
that all products belong to the cart's one shop, that each variant's stock is
sufficient,
and that monetary totals fit PostgreSQL `bigint`. It does not accept submitted
prices, line totals, subtotal, delivery fee, distance, or discount. Delivery
distance is the road route from the shop to the customer address; routing
failures return `503 DISTANCE_UNAVAILABLE` and fail closed. New rules use
integer paise/metres and are described in the backend README.
Order items snapshot the schema-supported product name, variant SKU and unit
price, cart quantity, line total, currency, and variant details (`variantId`,
label, unit, variant quantity, SKU, and unit price). Delivery
instructions, payment transactions/state, and cancellation reason are not
persisted. Migration 012 stores the order payment method (`cod` for current
order placement).

`POST /checkout/quote` and `POST /orders` return `401` unless `createApp` receives a trusted
`authenticateCustomer` middleware which must set
`req.auth.customerUserId` only after verifying customer authentication; the
order route additionally checks the corresponding active customer/user rows.
These routes never read customer identity from request data. Unit tests use a test-only
trusted middleware stub to exercise the transaction; the running server wires
the production OTP session authenticator when configured and accepts the
development-only token issuer only outside production. The allowlist check is
repeated during order placement. This policy checks pincodes only and does not
geofence coordinates. Customer order cancellation remains unavailable.

## Screen-by-screen mapping

| Existing screen | API mapping | Data and dependencies |
|---|---|---|
| Home and discovery sections | `GET /shops?q=...`, `GET /products?q=...` | Shops, partners, products. Curated sections, banners, store hours, distance, and offers are demo/UI data without schema support. |
| Delivery location bottom sheet | `POST /delivery/serviceability` during checkout | Requires coordinates and a six-digit pincode; checks `app.serviceable_pincodes`, not geocoding or a delivery polygon. |
| Categories | `GET /shops`, then `GET /shops/:shopId/categories` and `GET /products?shopId=...&categoryId=...` | Shops, partners, categories, products. App-wide category groups are not represented separately. |
| Search | `GET /products?q=...` and `GET /shops?q=...` | Product/shop name and description. The Flutter search index also assembles demo results; image and rating metadata are optional product attributes. |
| Product details and availability badge | `GET /products/:productId` | Products, variants, shops, partners; response includes image URLs and selectable variant prices/availability. |
| Product variants and related products | `GET /products` and `GET /products/:productId` | Variants include a stable `id`; the customer must select one before adding a product to the cart. |
| Recently viewed | No backend endpoint | Currently an in-memory Flutter store; no viewed-history table exists. |
| Restaurants list | `GET /shops?partnerType=restaurant` | Shops and partners. Rating, cuisine, ETA, distance, live open state, cover image, and offers have no schema fields. |
| Restaurant menu | `GET /shops/:shopId/categories` and `GET /products?shopId=...` | Categories and products belonging to the restaurant shop. |
| Partner category grid | `GET /partner-categories` | Active partner types and counts are dynamic; new normalized types appear without a Flutter code change. |
| Bakery list | `GET /shops?partnerType=bakery` | Supported after migration 004; the Home Page opens a generic backend shop list for the dynamic category. |
| Bakery menu | `GET /shops/:shopId/categories` and `GET /products?shopId=...` | Categories and products, once a bakery shop has been identified in catalog data. |
| Local stores list | `GET /shops?partnerType=grocery` | No local-store subtype, coordinates, delivery radius, rating, or ETA exists. |
| Local store catalog | `GET /shops/:shopId/categories` and `GET /products?shopId=...` | Categories and products for a selected shop. |
| Meat landing page | `GET /shops?partnerType=meat_shop` | Partner/shop records; shop merchandising, ratings, and delivery estimates are unavailable. |
| Chicken and mutton pages | `GET /shops/:shopId/categories` and `GET /products?shopId=...&categoryId=...` | Product/category catalog; no separate chicken/mutton classification field exists. |
| Meat catalog | `GET /shops/:shopId/categories` and `GET /products?shopId=...` | Products and categories for an identified meat shop. |
| Vegetables/fruits landing page | `GET /shops?partnerType=grocery` | Produce remains a grocery subtype; product `attributes.produce_type` distinguishes fruit and vegetable. |
| Produce catalog | `GET /shops?partnerType=grocery`, categories and `GET /products?partnerType=grocery` | Filters `attributes.produce_type` to `fruit` or `vegetable`; products without the attribute are not shown as produce. |
| Cart and cart access controls | Cart routes | Protected; unavailable until customer cart ownership is supported. |
| Checkout quote | `POST /checkout/quote` | Protected; authenticated calls fail closed while carts have no customer-owner relation. |
| Checkout, delivery options, instructions, address entry | `POST /delivery/serviceability`, `POST /orders` | Public serviceability can be checked; order placement is protected and unavailable until cart ownership is supported. No payment is completed. |
| Coupon picker and coupon validation | No endpoint available | Coupons/validation are demo data; no coupon or promotion table exists. |
| Payment choice | No payment endpoint available | Options are demo UI; no gateway is configured. Orders store `payment_method` as `cod` until a gateway is added. |
| Failed delivery and dues | Rider delivery-failure endpoint; `GET /me/dues`, `POST /me/dues/:entryId/dispute` | COD customer-fault failures create pending-review dues from the order total. Only admin confirmation makes a due block checkout; payments, waivers, and disputes are append-only ledger events. Prepaid failures create no due. |
| Order success and receipt | `POST /orders` response and `GET /me/orders/:orderId` | Order creation requires injected trusted auth; detail read is implemented behind the same boundary. Delivery OTP and cancellation reason are not stored. |
| Orders list | `GET /me/orders` | Implemented with pagination and authenticated customer scoping. |
| Order details | `GET /me/orders/:orderId` | Implemented; foreign and unknown order IDs return not found. |
| Order tracking | `GET /me/orders/:orderId`; live tracking requires another data/service source | `app.orders.status` exists, but no tracking events, rider position, or ETA is stored. |
| Order cancellation | Eventual `POST /me/orders/:orderId/cancel` | `app.orders.status` supports `cancelled`; identity, current-status transition rules, and a place to persist the UI cancellation reason are missing. |
| Refund status | No endpoint available | Refund records are demo/local data; no refund table or payment integration exists. |
| Profile | `GET /me/profile` | Implemented using `app.users` and `app.customers`; requires trusted authenticated identity. |
| Edit profile | `PATCH /me/profile` with `displayName`, `email`, and/or `phone` | Implemented; uniqueness is enforced by existing indexes. |
| Saved addresses | `GET/POST /me/addresses`, `PATCH/DELETE /me/addresses/:addressId` | Implemented using migration 003; configured Flutter flows load and save customer-owned address snapshots. |
| Wishlist and save-list controls | `GET /me/wishlist`, `POST /me/wishlist/items`, `DELETE /me/wishlist/items/:productId` | Implemented using migration 003; current Flutter store remains in-memory. |
| Parcel booking, history, and details | `POST/GET /me/parcels`, `GET /me/parcels/:parcelId` | Parcel requests require pickup/drop coordinates; the backend stores server-calculated road distance and fee. Records are requests only, with no dispatch or delivery completion. |
| Notifications | No endpoint available | Notifications are demo data; no notification table/provider exists. |
| Reviews list, write review, order rating | No endpoint available | No review/rating table exists. |
| Help and support | No endpoint available | Contact options/submissions have no support table/service. |
| Settings | No endpoint available | Preferences are local/UI behavior; no customer preference table exists. |
| Terms and conditions, privacy policy | Static app content; no API required | Content is bundled in the app; no CMS/content table exists. |

## Blockers before customer-specific APIs

1. Production customer-specific routes and order creation require trusted
   request identity. The running server's OTP authenticator is development-only;
   a production identity provider and JWT validation integration are still
   required.
2. Coupons, payment verification/transactions, refunds, notifications,
   reviews, and support requests have no tables or integrations. They are
   documented but not implemented.
3. Partner types are normalized identifiers and may be added without an app
   release. Admin tooling must store identifiers such as `sweet_shop` and
   approve the partner for its type to appear in the customer category list.
4. Delivery availability uses an active pincode table. A trusted geocoding or
   polygon provider is needed for precise location enforcement.
5. Apply all four database migrations before using database-backed endpoints.
