ALTER TABLE app.orders
  ADD COLUMN platform_fee_minor bigint NOT NULL DEFAULT 0,
  ADD CONSTRAINT orders_platform_fee_minor_nonnegative_check
    CHECK (platform_fee_minor >= 0),
  DROP CONSTRAINT orders_check,
  ADD CONSTRAINT orders_total_includes_platform_fee_check
    CHECK (
      total_minor =
        items_subtotal_minor + delivery_fee_minor + platform_fee_minor - discount_minor
    );
