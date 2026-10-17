ALTER TABLE app.orders
  ADD COLUMN rider_stage text NOT NULL DEFAULT 'accepted'
    CHECK (rider_stage IN ('accepted', 'picked_up', 'out_for_delivery', 'delivered'));

UPDATE app.orders
SET rider_stage = 'picked_up'
WHERE rider_id IS NOT NULL AND status = 'picked_up';

UPDATE app.orders
SET rider_stage = 'delivered'
WHERE rider_id IS NOT NULL AND status = 'delivered';

CREATE TABLE app.rider_delivery_earnings (
  order_id uuid PRIMARY KEY
    REFERENCES app.orders(id) ON DELETE RESTRICT,
  rider_id uuid NOT NULL
    REFERENCES app.riders(user_id) ON DELETE RESTRICT,
  payout_minor bigint NOT NULL CHECK (payout_minor >= 0),
  currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  delivered_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX rider_delivery_earnings_rider_delivered_idx
  ON app.rider_delivery_earnings (rider_id, delivered_at DESC);
