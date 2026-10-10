CREATE SCHEMA app;

CREATE TABLE app.users (
  id uuid PRIMARY KEY,
  email text,
  phone text,
  display_name text NOT NULL,
  system_role text NOT NULL DEFAULT 'customer'
    CHECK (system_role IN ('customer', 'rider', 'admin')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'suspended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE UNIQUE INDEX users_email_lower_unique
  ON app.users (lower(email))
  WHERE email IS NOT NULL;
CREATE UNIQUE INDEX users_phone_unique
  ON app.users (phone)
  WHERE phone IS NOT NULL;

CREATE TABLE app.customers (
  user_id uuid PRIMARY KEY REFERENCES app.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.riders (
  user_id uuid PRIMARY KEY REFERENCES app.users(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'suspended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.partners (
  id uuid PRIMARY KEY,
  partner_type text NOT NULL
    CHECK (partner_type IN ('restaurant', 'grocery', 'meat_shop', 'other')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'suspended', 'rejected')),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  legal_name text,
  contact_email text,
  contact_phone text,
  timezone text NOT NULL DEFAULT 'Asia/Kolkata',
  operating_details jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(operating_details) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app.partner_memberships (
  partner_id uuid NOT NULL REFERENCES app.partners(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES app.users(id) ON DELETE RESTRICT,
  role text NOT NULL
    CHECK (role IN ('owner', 'admin', 'manager', 'catalog_manager', 'order_manager')),
  status text NOT NULL DEFAULT 'invited'
    CHECK (status IN ('invited', 'active', 'suspended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (partner_id, user_id)
);
CREATE INDEX partner_memberships_user_status_idx
  ON app.partner_memberships (user_id, status, partner_id);

CREATE TABLE app.shops (
  id uuid PRIMARY KEY,
  partner_id uuid NOT NULL REFERENCES app.partners(id) ON DELETE RESTRICT,
  name text NOT NULL,
  slug text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'active', 'suspended', 'closed')),
  address jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(address) = 'object'),
  operating_details jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(operating_details) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (partner_id, slug),
  UNIQUE (id, partner_id)
);
CREATE INDEX shops_partner_status_idx ON app.shops (partner_id, status);

CREATE TABLE app.categories (
  id uuid PRIMARY KEY,
  partner_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  parent_category_id uuid,
  name text NOT NULL,
  slug text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (shop_id, slug),
  UNIQUE (id, shop_id, partner_id),
  FOREIGN KEY (shop_id, partner_id)
    REFERENCES app.shops (id, partner_id) ON DELETE RESTRICT,
  FOREIGN KEY (parent_category_id, shop_id, partner_id)
    REFERENCES app.categories (id, shop_id, partner_id) ON DELETE RESTRICT,
  CHECK (parent_category_id IS NULL OR parent_category_id <> id)
);
CREATE INDEX categories_shop_active_sort_idx
  ON app.categories (shop_id, is_active, sort_order);

CREATE TABLE app.products (
  id uuid PRIMARY KEY,
  partner_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  category_id uuid,
  sku text,
  name text NOT NULL,
  description text,
  price_minor bigint NOT NULL CHECK (price_minor >= 0),
  currency char(3) NOT NULL DEFAULT 'INR',
  inventory_quantity integer CHECK (inventory_quantity IS NULL OR inventory_quantity >= 0),
  is_available boolean NOT NULL DEFAULT true,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  attributes jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(attributes) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, shop_id, partner_id),
  FOREIGN KEY (shop_id, partner_id)
    REFERENCES app.shops (id, partner_id) ON DELETE RESTRICT,
  FOREIGN KEY (category_id, shop_id, partner_id)
    REFERENCES app.categories (id, shop_id, partner_id) ON DELETE RESTRICT,
  CHECK (currency ~ '^[A-Z]{3}$')
);
CREATE UNIQUE INDEX products_shop_sku_unique
  ON app.products (shop_id, sku)
  WHERE sku IS NOT NULL;
CREATE INDEX products_partner_shop_status_idx
  ON app.products (partner_id, shop_id, status, is_available);
CREATE INDEX products_category_idx ON app.products (shop_id, category_id);

CREATE TABLE app.orders (
  id uuid PRIMARY KEY,
  customer_user_id uuid NOT NULL REFERENCES app.customers(user_id) ON DELETE RESTRICT,
  partner_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'placed'
    CHECK (status IN (
      'placed', 'confirmed', 'preparing', 'ready_for_pickup',
      'picked_up', 'delivered', 'cancelled', 'rejected'
    )),
  currency char(3) NOT NULL DEFAULT 'INR' CHECK (currency ~ '^[A-Z]{3}$'),
  items_subtotal_minor bigint NOT NULL CHECK (items_subtotal_minor >= 0),
  delivery_fee_minor bigint NOT NULL DEFAULT 0 CHECK (delivery_fee_minor >= 0),
  discount_minor bigint NOT NULL DEFAULT 0 CHECK (discount_minor >= 0),
  total_minor bigint NOT NULL CHECK (total_minor >= 0),
  delivery_address_snapshot jsonb NOT NULL
    CHECK (jsonb_typeof(delivery_address_snapshot) = 'object'),
  placed_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, partner_id, shop_id),
  UNIQUE (id, partner_id, shop_id, currency),
  FOREIGN KEY (shop_id, partner_id)
    REFERENCES app.shops (id, partner_id) ON DELETE RESTRICT,
  CHECK (
    total_minor = items_subtotal_minor + delivery_fee_minor - discount_minor
  )
);
CREATE INDEX orders_customer_placed_idx
  ON app.orders (customer_user_id, placed_at DESC);
CREATE INDEX orders_partner_status_placed_idx
  ON app.orders (partner_id, status, placed_at DESC);
CREATE INDEX orders_shop_status_placed_idx
  ON app.orders (shop_id, status, placed_at DESC);

CREATE TABLE app.order_items (
  id uuid PRIMARY KEY,
  order_id uuid NOT NULL,
  partner_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  product_id uuid NOT NULL,
  product_name_snapshot text NOT NULL,
  sku_snapshot text,
  unit_price_minor bigint NOT NULL CHECK (unit_price_minor >= 0),
  quantity integer NOT NULL CHECK (quantity > 0),
  line_total_minor bigint NOT NULL CHECK (
    line_total_minor = unit_price_minor * quantity
  ),
  currency char(3) NOT NULL DEFAULT 'INR' CHECK (currency ~ '^[A-Z]{3}$'),
  variant_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(variant_snapshot) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (order_id, partner_id, shop_id, currency)
    REFERENCES app.orders (id, partner_id, shop_id, currency) ON DELETE RESTRICT,
  FOREIGN KEY (product_id, shop_id, partner_id)
    REFERENCES app.products (id, shop_id, partner_id) ON DELETE RESTRICT
);
CREATE INDEX order_items_order_idx ON app.order_items (order_id);
CREATE INDEX order_items_product_idx ON app.order_items (product_id);

CREATE FUNCTION app.prevent_order_item_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'Order item snapshots are immutable';
END;
$$;

CREATE TRIGGER order_items_immutable
BEFORE UPDATE OR DELETE ON app.order_items
FOR EACH ROW EXECUTE FUNCTION app.prevent_order_item_mutation();
