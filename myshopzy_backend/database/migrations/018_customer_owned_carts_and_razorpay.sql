ALTER TABLE app.customer_carts
  ADD COLUMN customer_user_id uuid
    REFERENCES app.customers(user_id) ON DELETE RESTRICT;

CREATE INDEX customer_carts_customer_user_id_idx
  ON app.customer_carts (customer_user_id)
  WHERE customer_user_id IS NOT NULL;