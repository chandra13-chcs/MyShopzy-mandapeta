CREATE TABLE IF NOT EXISTS app.product_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  partner_id uuid NOT NULL,
  shop_id uuid NOT NULL,
  label text NOT NULL CHECK (length(btrim(label)) BETWEEN 1 AND 20),
  unit text NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0),
  price_minor bigint NOT NULL CHECK (price_minor >= 0),
  stock integer CHECK (stock >= 0),
  sku text,
  is_available boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, label),
  UNIQUE (id, product_id, shop_id, partner_id),
  FOREIGN KEY (product_id, shop_id, partner_id)
    REFERENCES app.products (id, shop_id, partner_id) ON DELETE RESTRICT,
  FOREIGN KEY (shop_id, partner_id)
    REFERENCES app.shops (id, partner_id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX IF NOT EXISTS product_variants_shop_sku_unique
  ON app.product_variants (shop_id, sku)
  WHERE sku IS NOT NULL;
CREATE INDEX IF NOT EXISTS product_variants_product_sort_idx
  ON app.product_variants (product_id, sort_order, id);

INSERT INTO app.product_variants (
  product_id,
  partner_id,
  shop_id,
  label,
  unit,
  quantity,
  price_minor,
  stock,
  sku,
  is_available,
  sort_order
)
SELECT
  p.id,
  p.partner_id,
  p.shop_id,
  '1 unit',
  'each',
  1,
  p.price_minor,
  p.inventory_quantity,
  p.sku,
  p.is_available,
  0
FROM app.products AS p
ON CONFLICT (product_id, label) DO NOTHING;

ALTER TABLE app.products
  ADD COLUMN IF NOT EXISTS image_url text,
  ADD COLUMN IF NOT EXISTS thumb_url text;

ALTER TABLE app.customer_cart_items
  ADD COLUMN IF NOT EXISTS variant_id uuid;

UPDATE app.customer_cart_items AS ci
SET variant_id = variant.id
FROM app.product_variants AS variant
WHERE ci.variant_id IS NULL
  AND variant.product_id = ci.product_id
  AND variant.shop_id = ci.shop_id
  AND variant.partner_id = ci.partner_id
  AND variant.label = '1 unit';

ALTER TABLE app.customer_cart_items
  ALTER COLUMN variant_id SET NOT NULL;

ALTER TABLE app.customer_cart_items
  DROP CONSTRAINT IF EXISTS customer_cart_items_pkey;

ALTER TABLE app.customer_cart_items
  ADD CONSTRAINT customer_cart_items_pkey
  PRIMARY KEY (cart_id, product_id, variant_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'customer_cart_items_variant_fk'
      AND conrelid = 'app.customer_cart_items'::regclass
  ) THEN
    ALTER TABLE app.customer_cart_items
      ADD CONSTRAINT customer_cart_items_variant_fk
      FOREIGN KEY (variant_id, product_id, shop_id, partner_id)
      REFERENCES app.product_variants (id, product_id, shop_id, partner_id)
      ON DELETE RESTRICT;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS customer_cart_items_variant_idx
  ON app.customer_cart_items (variant_id);
