ALTER TABLE app.orders
  ADD COLUMN payment_method text NOT NULL DEFAULT 'cod'
    CHECK (payment_method IN ('cod', 'prepaid')),
  ADD COLUMN delivery_failure_reason text
    CHECK (
      delivery_failure_reason IS NULL
      OR delivery_failure_reason IN (
        'customer_refused',
        'customer_unreachable',
        'wrong_address_by_customer'
      )
    ),
  ADD COLUMN delivery_failed_at timestamptz,
  ADD COLUMN delivery_failure_note text
    CHECK (
      delivery_failure_note IS NULL
      OR char_length(delivery_failure_note) <= 300
    ),
  ADD COLUMN delivery_failure_attempts integer
    CHECK (
      delivery_failure_attempts IS NULL
      OR delivery_failure_attempts BETWEEN 0 AND 10
    ),
  ADD COLUMN delivery_failure_latitude double precision
    CHECK (
      delivery_failure_latitude IS NULL
      OR delivery_failure_latitude BETWEEN -90 AND 90
    ),
  ADD COLUMN delivery_failure_longitude double precision
    CHECK (
      delivery_failure_longitude IS NULL
      OR delivery_failure_longitude BETWEEN -180 AND 180
    );

ALTER TABLE app.orders
  DROP CONSTRAINT orders_status_check,
  ADD CONSTRAINT orders_status_check
    CHECK (status IN (
      'placed', 'confirmed', 'preparing', 'getting_packed',
      'ready_for_pickup', 'picked_up', 'out_for_delivery',
      'delivered', 'delivery_failed', 'cancelled', 'rejected'
    ));

CREATE TABLE app.customer_ledger_entries (
  id uuid PRIMARY KEY,
  customer_user_id uuid NOT NULL
    REFERENCES app.customers(user_id) ON DELETE RESTRICT,
  order_id uuid REFERENCES app.orders(id) ON DELETE RESTRICT,
  related_entry_id uuid
    REFERENCES app.customer_ledger_entries(id) ON DELETE RESTRICT,
  entry_type text NOT NULL
    CHECK (entry_type IN (
      'due_pending_review',
      'due_confirmed',
      'payment_received',
      'waived'
    )),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  reason text,
  note text,
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(evidence) = 'object'),
  created_by_actor text NOT NULL
    CHECK (
      created_by_actor = 'system'
      OR created_by_actor ~
        '^(rider|admin|customer):[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    ),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX customer_ledger_entries_customer_created_idx
  ON app.customer_ledger_entries (customer_user_id, created_at DESC);

CREATE UNIQUE INDEX customer_ledger_entries_one_due_per_order_idx
  ON app.customer_ledger_entries (order_id)
  WHERE entry_type = 'due_pending_review' AND related_entry_id IS NULL;

CREATE INDEX customer_ledger_entries_related_entry_idx
  ON app.customer_ledger_entries (related_entry_id)
  WHERE related_entry_id IS NOT NULL;

CREATE UNIQUE INDEX customer_ledger_entries_one_confirmation_per_due_idx
  ON app.customer_ledger_entries (related_entry_id)
  WHERE entry_type = 'due_confirmed' AND evidence->>'kind' = 'confirmation';

CREATE UNIQUE INDEX customer_ledger_entries_one_waiver_per_due_idx
  ON app.customer_ledger_entries (related_entry_id)
  WHERE entry_type = 'waived' AND evidence->>'kind' = 'waiver';

CREATE FUNCTION app.prevent_customer_ledger_entry_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'Customer ledger entries are append-only';
END;
$$;

CREATE TRIGGER customer_ledger_entries_append_only
BEFORE UPDATE OR DELETE ON app.customer_ledger_entries
FOR EACH ROW EXECUTE FUNCTION app.prevent_customer_ledger_entry_mutation();
