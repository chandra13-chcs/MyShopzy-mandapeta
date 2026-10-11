CREATE TABLE app.customer_saved_addresses (
  id uuid PRIMARY KEY,
  customer_user_id uuid NOT NULL
    REFERENCES app.customers(user_id) ON DELETE RESTRICT,
  label text NOT NULL CHECK (length(btrim(label)) BETWEEN 1 AND 40),
  address_snapshot jsonb NOT NULL
    CHECK (jsonb_typeof(address_snapshot) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, customer_user_id)
);
CREATE INDEX customer_saved_addresses_customer_idx
  ON app.customer_saved_addresses (customer_user_id, created_at, id);

CREATE TABLE app.customer_wishlist_items (
  customer_user_id uuid NOT NULL
    REFERENCES app.customers(user_id) ON DELETE RESTRICT,
  product_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  partner_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (customer_user_id, product_id),
  FOREIGN KEY (product_id, shop_id, partner_id)
    REFERENCES app.products (id, shop_id, partner_id) ON DELETE RESTRICT
);
CREATE INDEX customer_wishlist_items_product_idx
  ON app.customer_wishlist_items (product_id);

CREATE TABLE app.parcel_bookings (
  id uuid PRIMARY KEY,
  customer_user_id uuid NOT NULL
    REFERENCES app.customers(user_id) ON DELETE RESTRICT,
  pickup_location text NOT NULL
    CHECK (length(btrim(pickup_location)) BETWEEN 1 AND 300),
  drop_location text NOT NULL
    CHECK (length(btrim(drop_location)) BETWEEN 1 AND 300),
  parcel_type text NOT NULL
    CHECK (parcel_type IN ('Documents', 'Food', 'Clothing', 'Electronics', 'Other')),
  weight_grams integer NOT NULL CHECK (weight_grams BETWEEN 1 AND 20000),
  instructions text NOT NULL DEFAULT ''
    CHECK (length(instructions) <= 1000),
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX parcel_bookings_customer_created_idx
  ON app.parcel_bookings (customer_user_id, created_at DESC);
