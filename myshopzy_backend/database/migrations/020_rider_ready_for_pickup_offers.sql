CREATE INDEX orders_ready_for_pickup_riders_idx
  ON app.orders (placed_at, id)
  WHERE status = 'ready_for_pickup' AND rider_id IS NULL;
