ALTER TABLE app.orders
  ADD COLUMN rider_id uuid REFERENCES app.riders(user_id) ON DELETE RESTRICT;

ALTER TABLE app.orders
  DROP CONSTRAINT orders_status_check,
  ADD CONSTRAINT orders_status_check
    CHECK (status IN (
      'placed', 'confirmed', 'preparing', 'getting_packed',
      'ready_for_pickup', 'picked_up', 'out_for_delivery',
      'delivered', 'cancelled', 'rejected'
    ));

CREATE INDEX orders_available_for_riders_idx
  ON app.orders (placed_at, id)
  WHERE status = 'getting_packed' AND rider_id IS NULL;

ALTER TABLE app.riders
  ADD COLUMN current_latitude double precision
    CHECK (current_latitude IS NULL OR current_latitude BETWEEN -90 AND 90),
  ADD COLUMN current_longitude double precision
    CHECK (current_longitude IS NULL OR current_longitude BETWEEN -180 AND 180),
  ADD COLUMN is_online boolean NOT NULL DEFAULT false;
