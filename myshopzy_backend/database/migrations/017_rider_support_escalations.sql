BEGIN;

ALTER TABLE app.orders
  ADD COLUMN rider_arrived_at timestamptz,
  ADD COLUMN support_escalated_at timestamptz;

CREATE INDEX orders_support_escalation_queue_idx
  ON app.orders (rider_arrived_at, id)
  WHERE rider_arrived_at IS NOT NULL
    AND status NOT IN ('delivered', 'delivery_failed');

CREATE TABLE app.order_support_resolutions (
  order_id uuid PRIMARY KEY
    REFERENCES app.orders(id) ON DELETE RESTRICT,
  outcome text NOT NULL
    CHECK (outcome IN (
      'customer_reached',
      'customer_unreachable',
      'customer_refused'
    )),
  support_reference text NOT NULL
    CHECK (char_length(support_reference) BETWEEN 3 AND 100),
  note text
    CHECK (note IS NULL OR char_length(note) <= 300),
  resolved_by uuid NOT NULL REFERENCES app.users(id) ON DELETE RESTRICT,
  resolved_at timestamptz NOT NULL DEFAULT now()
);

COMMIT;
