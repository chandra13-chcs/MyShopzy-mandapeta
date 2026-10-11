CREATE TABLE app.customer_carts (
  id uuid PRIMARY KEY,
  token_hash bytea NOT NULL UNIQUE
    CHECK (octet_length(token_hash) = 32),
  shop_id uuid,
  partner_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((shop_id IS NULL) = (partner_id IS NULL)),
  UNIQUE (id, shop_id, partner_id),
  FOREIGN KEY (shop_id, partner_id)
    REFERENCES app.shops (id, partner_id) ON DELETE RESTRICT
);

CREATE TABLE app.customer_cart_items (
  cart_id uuid NOT NULL,
  product_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  partner_id uuid NOT NULL,
  quantity integer NOT NULL CHECK (quantity BETWEEN 1 AND 99),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (cart_id, product_id),
  FOREIGN KEY (cart_id, shop_id, partner_id)
    REFERENCES app.customer_carts (id, shop_id, partner_id)
    ON DELETE CASCADE,
  FOREIGN KEY (product_id, shop_id, partner_id)
    REFERENCES app.products (id, shop_id, partner_id) ON DELETE RESTRICT
);

CREATE INDEX customer_cart_items_product_idx
  ON app.customer_cart_items (product_id);
