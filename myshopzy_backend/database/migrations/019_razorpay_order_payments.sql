ALTER TABLE app.orders
  DROP CONSTRAINT orders_status_check,
  ADD CONSTRAINT orders_status_check
    CHECK (status IN (
      'payment_pending', 'placed', 'confirmed', 'preparing', 'packed',
      'ready_for_pickup', 'picked_up', 'out_for_delivery', 'delivered',
      'delivery_failed', 'cancelled', 'rejected'
    ));

CREATE TABLE app.order_payment_attempts (
  id uuid PRIMARY KEY,
  order_id uuid NOT NULL UNIQUE
    REFERENCES app.orders(id) ON DELETE RESTRICT,
  customer_user_id uuid NOT NULL
    REFERENCES app.customers(user_id) ON DELETE RESTRICT,
  checkout_request_id uuid NOT NULL,
  provider text NOT NULL DEFAULT 'razorpay'
    CHECK (provider = 'razorpay'),
  provider_order_id text UNIQUE,
  provider_payment_id text UNIQUE,
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  currency char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'verified')),
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (customer_user_id, checkout_request_id),
  CHECK (
    (status = 'verified')
    = (provider_payment_id IS NOT NULL AND verified_at IS NOT NULL)
  ),
  CHECK (status <> 'verified' OR provider_order_id IS NOT NULL)
);

CREATE INDEX order_payment_attempts_customer_created_idx
  ON app.order_payment_attempts (customer_user_id, created_at DESC);
