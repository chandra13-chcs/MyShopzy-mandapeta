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

Additive migrations 003 and 004 add saved-address, wishlist, parcel-booking,
dynamic partner-category, and delivery-serviceability storage. The partner
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
| `POST /me/parcels` | Pickup/drop strings, UI parcel type, weight `0 < kg <= 20` (up to three decimal places), optional instructions | `app.parcel_bookings`; creates a `requested` booking, `201` |

OTP codes expire after five minutes, allow five verification attempts, and have
a 30-second resend cooldown. Requests are limited to three per phone per 15
minutes and ten per source IP per hour. Codes, phone numbers, and IP addresses
are not stored in plaintext in OTP challenge/rate-limit tables. Unknown and
existing phone numbers follow the same request contract; a customer account
is only created after code verification.
| `GET /me/parcels` | Optional `limit` (1–100), `offset` | Authenticated customer's booking list |
| `GET /me/parcels/:parcelId` | UUID path | Owner-scoped booking details; foreign and missing IDs return `404` |

Parcel booking records express a request only. There is no dispatch, distance
verification, delivery price, or completion integration, so the API does not
claim that a parcel has been accepted or delivered.

## Cart, checkout, and order API foundations

The additive migration `002_customer_carts.sql` adds
`app.customer_carts` and `app.customer_cart_items`; migration
`008_product_variants_and_images.sql` adds `variant_id` and changes cart-line
identity to `(cart_id, product_id, variant_id)`. Each cart is addressed only by
a random 256-bit bearer token returned once by cart creation; the database
stores its SHA-256 hash. This is an anonymous cart capability, not a customer
identity. A caller must protect the token, and possession grants access to
that cart.

| Endpoint | Request | Response / behavior | PostgreSQL tables |
|---|---|---|---|
| `POST /carts` | Empty JSON body or no body | `201` with one-time `data.cartToken` | `app.customer_carts` |
| `GET /cart` | `X-Cart-Token` header | Cart shop, current variant price, `variantId`, `variantLabel`, quantities, availability, and subtotal | Cart tables, products, product variants, shops, partners |
| `POST /cart/items` | `X-Cart-Token`; `{ "productId": "<uuid>", "variantId": "<uuid>", "quantity": 1 }` (quantity optional, defaults to 1) | Adds quantity to the product/variant cart line; variant must belong to the product and its shop; server reads variant price and stock | Cart tables and catalog tables |
| `PATCH /cart/items/:productId/:variantId` | `X-Cart-Token`; `{ "quantity": 1 }` | Sets quantity for that product/variant line; quantity must be 1–99 and within variant stock when tracked | Cart tables and catalog tables |
| `DELETE /cart/items/:productId/:variantId` | `X-Cart-Token` | `204` after removal of that product/variant line | Cart tables |
| `DELETE /cart/items` | `X-Cart-Token` | Clears cart contents and releases the cart's single-shop binding | Cart tables |
| `POST /checkout/quote` | `X-Cart-Token`; no client price/total fields | Items (including `variantId` and `variantLabel`), currency, subtotal, delivery fee, discount, and total; prices are freshly read from PostgreSQL variants | Cart tables, products, product variants, shops, partners |
| `POST /orders` | `X-Cart-Token`; `{ "deliveryAddress": { ... , "pincode": "533308" } }`; trusted authenticated customer context | `201` with order ID/status and server-calculated totals. Requires the address pincode to be active in `app.serviceable_pincodes`; order and immutable item snapshots are inserted transactionally. | Customers, users, cart tables, products, product variants, shops, partners, serviceable pincodes, orders, order items |

Order placement checks that every product, shop, and partner is active/approved,
that all products belong to the cart's one shop, that each variant's stock is
sufficient,
and that monetary totals fit PostgreSQL `bigint`. It does not accept submitted
prices, line totals, subtotal, delivery fee, or discount. Delivery fee and
discount are fixed to zero because no delivery pricing/coupon rules exist.
Order items snapshot the schema-supported product name, variant SKU and unit
price, cart quantity, line total, currency, and variant details (`variantId`,
label, unit, variant quantity, SKU, and unit price). Delivery
instructions, payment details, and cancellation reason are not persisted.

`POST /orders` returns `401` unless `createApp` receives a trusted
`authenticateCustomer` middleware which must set
`req.auth.customerUserId` only after verifying customer authentication; the
route additionally checks the corresponding active customer/user rows. It
never reads customer identity from request data. Unit tests use a test-only
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
| Cart and cart access controls | `POST /carts`, `GET /cart`, `POST /cart/items`, `PATCH /cart/items/:productId/:variantId`, `DELETE /cart/items/:productId/:variantId`, `DELETE /cart/items` | Implemented using anonymous bearer cart tokens. Add requests require `{ "productId": "<uuid>", "variantId": "<uuid>", "quantity": 1 }`; cart lines are unique by product and variant and expose `variantId`, `variantLabel`, and variant `priceMinor`. |
| Checkout quote | `POST /checkout/quote` | Uses server-side variant prices and stock, one-shop validation, and zero delivery/discount pending pricing rules. Quote lines include `variantId`, `variantLabel`, `priceMinor`, and `lineTotalMinor`. |
| Checkout, delivery options, instructions, address entry | `POST /delivery/serviceability`, `POST /orders`; trusted auth middleware required | Order totals and immutable variant snapshots are generated from server-side cart variants. Serviceability is checked before checkout and again at order placement. Delivery-fee rules, coupons, and instruction fields are not modeled. Running-server authentication is development-only. |
| Coupon picker and coupon validation | No endpoint available | Coupons/validation are demo data; no coupon or promotion table exists. |
| Payment choice | No endpoint available | Options are demo UI; no payment table or provider is configured. |
| Order success and receipt | `POST /orders` response and `GET /me/orders/:orderId` | Order creation requires injected trusted auth; detail read is implemented behind the same boundary. Payment state, payment method, delivery OTP, and cancellation reason are not stored. |
| Orders list | `GET /me/orders` | Implemented with pagination and authenticated customer scoping. |
| Order details | `GET /me/orders/:orderId` | Implemented; foreign and unknown order IDs return not found. |
| Order tracking | `GET /me/orders/:orderId`; live tracking requires another data/service source | `app.orders.status` exists, but no tracking events, rider position, or ETA is stored. |
| Order cancellation | Eventual `POST /me/orders/:orderId/cancel` | `app.orders.status` supports `cancelled`; identity, current-status transition rules, and a place to persist the UI cancellation reason are missing. |
| Refund status | No endpoint available | Refund records are demo/local data; no refund table or payment integration exists. |
| Profile | `GET /me/profile` | Implemented using `app.users` and `app.customers`; requires trusted authenticated identity. |
| Edit profile | `PATCH /me/profile` with `displayName`, `email`, and/or `phone` | Implemented; uniqueness is enforced by existing indexes. |
| Saved addresses | `GET/POST /me/addresses`, `PATCH/DELETE /me/addresses/:addressId` | Implemented using migration 003; configured Flutter flows load and save customer-owned address snapshots. |
| Wishlist and save-list controls | `GET /me/wishlist`, `POST /me/wishlist/items`, `DELETE /me/wishlist/items/:productId` | Implemented using migration 003; current Flutter store remains in-memory. |
| Parcel booking, history, and details | `POST/GET /me/parcels`, `GET /me/parcels/:parcelId` | Flutter uses these APIs when configured and surfaces authentication errors; records are requests only, with no dispatch, distance verification, or price. |
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
