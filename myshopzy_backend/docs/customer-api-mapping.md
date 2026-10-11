# Customer app API mapping

This mapping follows the current Flutter screens, the existing PostgreSQL
migrations, and the additive customer API migrations.
Authentication, login, and signup are intentionally excluded. Implemented
catalog endpoints are public reads; a customer ID supplied by a client is not
a trusted identity.

## Implemented API contract

All routes use `/api/v1`. Successful list responses have
`{ "data": [...], "pagination": { "limit": 20, "offset": 0 } }`; resource
responses have `{ "data": { ... } }`. Errors have
`{ "error": { "code": "...", "message": "..." } }`.

| Endpoint | Request | Response fields | PostgreSQL tables / behavior |
|---|---|---|---|
| `GET /shops` | Optional `partnerType` (`restaurant`, `grocery`, `meat_shop`, `other`), `q`, `limit` (1–100), `offset` | Shop `id`, `partner_id`, `name`, `slug`, `address`, `operating_details`, `partner_name`, `partner_type` | `app.shops`, `app.partners`; only active shops of approved partners |
| `GET /shops/:shopId/categories` | UUID `shopId` | Category `id`, `shop_id`, `parent_category_id`, `name`, `slug`, `sort_order` | `app.categories`, `app.shops`, `app.partners`; active categories of an active shop and approved partner |
| `GET /products` | Optional UUID `shopId`, UUID `categoryId`, `partnerType`, `q`, `limit` (1–100), `offset` | Product `id`, `partner_id`, `shop_id`, `category_id`, `sku`, `name`, `description`, `price_minor`, `currency`, `inventory_quantity`, `is_available`, `attributes`, `shop_name`, `partner_name`, `partner_type` | `app.products`, `app.shops`, `app.partners`; only active and available products from active shops and approved partners |
| `GET /products/:productId` | UUID `productId` | Same product fields as `GET /products` | Same tables and public/available visibility rules |

Prices are returned in the database's minor currency unit (`price_minor`, paise
for INR). No image, rating, offer, delivery ETA, or product-variant fields are
fabricated: those are not typed columns in the existing schema. `attributes`
is returned as stored JSON; the API does not assume undocumented keys.
All request values are passed separately as PostgreSQL parameters. Invalid
query values return `400`, missing public resources return `404`, unavailable
PostgreSQL returns `503`, and database failures return a generic `500`.

## Customer account API foundations

The additive migration `003_customer_account_parcels.sql` adds saved-address,
wishlist, and parcel-booking tables. All customer routes below require a
trusted `authenticateCustomer` middleware which sets
`req.auth.customerUserId`; they return the same `401` response when no trusted
middleware is configured. Client-supplied user IDs are never used as identity.

| Endpoint | Request / result | Tables and scope |
|---|---|---|
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
| `GET /me/parcels` | Optional `limit` (1–100), `offset` | Authenticated customer's booking list |
| `GET /me/parcels/:parcelId` | UUID path | Owner-scoped booking details; foreign and missing IDs return `404` |

Parcel booking records express a request only. There is no dispatch, distance
verification, delivery price, or completion integration, so the API does not
claim that a parcel has been accepted or delivered.

## Cart, checkout, and order API foundations

The additive migration `002_customer_carts.sql` adds
`app.customer_carts` and `app.customer_cart_items`. Each cart is addressed
only by a random 256-bit bearer token returned once by cart creation; the
database stores its SHA-256 hash. This is an anonymous cart capability, not a
customer identity. A caller must protect the token, and possession grants
access to that cart.

| Endpoint | Request | Response / behavior | PostgreSQL tables |
|---|---|---|---|
| `POST /carts` | Empty JSON body or no body | `201` with one-time `data.cartToken` | `app.customer_carts` |
| `GET /cart` | `X-Cart-Token` header | Cart shop, current product prices, quantities, availability, and subtotal | Cart tables, products, shops, partners |
| `POST /cart/items` | `X-Cart-Token`; `{ "productId": "<uuid>", "quantity": 1 }` (quantity optional, defaults to 1) | Adds quantity to the product's cart quantity; server reads product price and stock | Cart tables and catalog tables |
| `PATCH /cart/items/:productId` | `X-Cart-Token`; `{ "quantity": 1 }` | Sets quantity; quantity must be 1–99 and within available inventory when inventory is tracked | Cart tables and catalog tables |
| `DELETE /cart/items/:productId` | `X-Cart-Token` | `204` after removal | Cart tables |
| `DELETE /cart/items` | `X-Cart-Token` | Clears cart contents and releases the cart's single-shop binding | Cart tables |
| `POST /checkout/quote` | `X-Cart-Token`; no client price/total fields | Items, currency, subtotal, delivery fee, discount, and total; prices are freshly read from PostgreSQL | Cart tables, products, shops, partners |
| `POST /orders` | `X-Cart-Token`; `{ "deliveryAddress": { ... } }`; trusted authenticated customer context | `201` with order ID/status and server-calculated totals. Order and immutable item snapshots are inserted transactionally; tracked inventory is decremented and the cart is cleared in that transaction. | Customers, users, cart tables, products, shops, partners, orders, order items |

Order placement checks that every product, shop, and partner is active/approved,
that all products belong to the cart's one shop, that inventory is sufficient,
and that monetary totals fit PostgreSQL `bigint`. It does not accept submitted
prices, line totals, subtotal, delivery fee, or discount. Delivery fee and
discount are fixed to zero because no delivery pricing/coupon rules exist.
Order items snapshot the schema-supported product name, SKU, unit price,
quantity, line total, and currency. Unsupported product variants, delivery
instructions, payment details, and cancellation reason are not persisted.

The server has no authentication implementation.
`POST /orders` returns `401` by default. `createApp` supports an injected
trusted `authenticateCustomer` middleware which must set
`req.auth.customerUserId` only after verifying customer authentication; the
route additionally checks the corresponding active customer/user rows. It
never reads customer identity from request data. Unit tests use a test-only
trusted middleware stub to exercise the transaction; this does not enable
order placement in the running app. Customer order read/cancel APIs remain
unavailable.

## Screen-by-screen mapping

| Existing screen | API mapping | Data and dependencies |
|---|---|---|
| Home and discovery sections | `GET /shops?q=...`, `GET /products?q=...` | Shops, partners, products. Curated sections, banners, store hours, distance, and offers are demo/UI data without schema support. |
| Delivery location bottom sheet | None currently | Address suggestions and location selection are demo/UI state; no geocoding or customer-address service is configured. |
| Categories | `GET /shops`, then `GET /shops/:shopId/categories` and `GET /products?shopId=...&categoryId=...` | Shops, partners, categories, products. App-wide category groups are not represented separately. |
| Search | `GET /products?q=...` and `GET /shops?q=...` | Product/shop name and description. The Flutter search index also assembles demo results; ratings and images are absent from the schema. |
| Product details and availability badge | `GET /products/:productId` | Products, shops, partners; response reflects `status`, `is_available`, and inventory. No image or rating fields exist. |
| Product variants and related products | Related products can use `GET /products?shopId=...&categoryId=...` | No product-variant table exists; `attributes` has no agreed variant contract. |
| Recently viewed | No backend endpoint | Currently an in-memory Flutter store; no viewed-history table exists. |
| Restaurants list | `GET /shops?partnerType=restaurant` | Shops and partners. Rating, cuisine, ETA, distance, live open state, cover image, and offers have no schema fields. |
| Restaurant menu | `GET /shops/:shopId/categories` and `GET /products?shopId=...` | Categories and products belonging to the restaurant shop. |
| Bakery list | `GET /shops?partnerType=grocery` | Bakery is not a `partner_type`; distinguishing it from grocery shops needs an agreed data convention, not inferred API values. |
| Bakery menu | `GET /shops/:shopId/categories` and `GET /products?shopId=...` | Categories and products, once a bakery shop has been identified in catalog data. |
| Local stores list | `GET /shops?partnerType=grocery` | No local-store subtype, coordinates, delivery radius, rating, or ETA exists. |
| Local store catalog | `GET /shops/:shopId/categories` and `GET /products?shopId=...` | Categories and products for a selected shop. |
| Meat landing page | `GET /shops?partnerType=meat_shop` | Partner/shop records; shop merchandising, ratings, and delivery estimates are unavailable. |
| Chicken and mutton pages | `GET /shops/:shopId/categories` and `GET /products?shopId=...&categoryId=...` | Product/category catalog; no separate chicken/mutton classification field exists. |
| Meat catalog | `GET /shops/:shopId/categories` and `GET /products?shopId=...` | Products and categories for an identified meat shop. |
| Vegetables/fruits landing page | `GET /shops?partnerType=grocery` | Produce is not a `partner_type`; subtype and produce merchandising need defined catalog data. |
| Produce catalog | `GET /shops/:shopId/categories` and `GET /products?shopId=...&categoryId=...` | Categories/products; no produce-specific availability or delivery rules exist. |
| Cart and cart access controls | `POST /carts`, `GET /cart`, `POST /cart/items`, `PATCH /cart/items/:productId`, `DELETE /cart/items/:productId`, `DELETE /cart/items` | Implemented using anonymous bearer cart tokens and migration 002. Flutter still uses its in-memory `CartStore`; it has not been wired to these APIs. |
| Checkout quote | `POST /checkout/quote` | Implemented; uses current PostgreSQL prices, one-shop validation, and zero delivery/discount pending pricing rules. |
| Checkout, delivery options, instructions, address entry | `POST /orders` foundation; trusted auth middleware required | Transactional placement and address snapshot are implemented when trusted auth is injected. Saved address CRUD is available, but delivery-fee rules, coupons, and instruction fields are not modeled. No auth middleware exists in the running app. |
| Coupon picker and coupon validation | No endpoint available | Coupons/validation are demo data; no coupon or promotion table exists. |
| Payment choice | No endpoint available | Options are demo UI; no payment table or provider is configured. |
| Order success and receipt | `POST /orders` response and `GET /me/orders/:orderId` | Order creation requires injected trusted auth; detail read is implemented behind the same boundary. Payment state, payment method, delivery OTP, and cancellation reason are not stored. |
| Orders list | `GET /me/orders` | Implemented with pagination and authenticated customer scoping. |
| Order details | `GET /me/orders/:orderId` | Implemented; foreign and unknown order IDs return not found. |
| Order tracking | Eventual `GET /me/orders/:orderId`; live tracking requires another data/service source | `app.orders.status` exists, but no tracking events, rider position, or ETA is stored. |
| Order cancellation | Eventual `POST /me/orders/:orderId/cancel` | `app.orders.status` supports `cancelled`; identity, current-status transition rules, and a place to persist the UI cancellation reason are missing. |
| Refund status | No endpoint available | Refund records are demo/local data; no refund table or payment integration exists. |
| Profile | `GET /me/profile` | Implemented using `app.users` and `app.customers`; requires trusted authenticated identity. |
| Edit profile | `PATCH /me/profile` with `displayName`, `email`, and/or `phone` | Implemented; uniqueness is enforced by existing indexes. |
| Saved addresses | `GET/POST /me/addresses`, `PATCH/DELETE /me/addresses/:addressId` | Implemented using migration 003; current Flutter addresses remain demo data. |
| Wishlist and save-list controls | `GET /me/wishlist`, `POST /me/wishlist/items`, `DELETE /me/wishlist/items/:productId` | Implemented using migration 003; current Flutter store remains in-memory. |
| Parcel booking and parcel summary | `POST/GET /me/parcels`, `GET /me/parcels/:parcelId` | Implemented as requested bookings using migration 003; dispatch, distance validation, and price are unavailable. |
| Notifications | No endpoint available | Notifications are demo data; no notification table/provider exists. |
| Reviews list, write review, order rating | No endpoint available | No review/rating table exists. |
| Help and support | No endpoint available | Contact options/submissions have no support table/service. |
| Settings | No endpoint available | Preferences are local/UI behavior; no customer preference table exists. |
| Terms and conditions, privacy policy | Static app content; no API required | Content is bundled in the app; no CMS/content table exists. |

## Blockers before customer-specific APIs

1. Customer-specific routes and order creation require trusted request
   identity. Login, signup, and JWT work are deliberately deferred; the
   routes return `401` unless trusted authentication middleware is injected.
2. Coupons, payment verification/transactions, refunds, notifications,
   reviews, and support requests have no tables or integrations. They are
   documented but not implemented.
3. Catalog partner types are limited to restaurant, grocery, meat shop, and
   other. More specific bakery/local-store/produce classification and missing
   UI merchandising attributes need agreed data conventions before these
   flows can be represented faithfully.
4. The initial, cart, and customer-account migrations are present but
   unapplied. Endpoints need all three migrations; no migration has been run
   and no database connection was tested.
