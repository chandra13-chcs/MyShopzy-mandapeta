BEGIN;

ALTER TABLE app.orders
  DROP CONSTRAINT orders_status_check;

UPDATE app.orders
SET status = 'packed'
WHERE status = 'getting_packed';

ALTER TABLE app.orders
  ADD CONSTRAINT orders_status_check
    CHECK (status IN (
      'placed', 'confirmed', 'preparing', 'packed',
      'ready_for_pickup', 'picked_up', 'out_for_delivery',
      'delivered', 'delivery_failed', 'cancelled', 'rejected'
    ));

DROP INDEX app.orders_available_for_riders_idx;

CREATE INDEX orders_available_for_riders_idx
  ON app.orders (placed_at, id)
  WHERE status = 'packed' AND rider_id IS NULL;

ALTER TABLE app.riders
  ADD COLUMN current_location_accuracy double precision,
  ADD COLUMN current_location_updated_at timestamptz,
  ADD CONSTRAINT riders_location_accuracy_nonnegative_check
    CHECK (
      current_location_accuracy IS NULL OR current_location_accuracy >= 0
    );

COMMIT;
