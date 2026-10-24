ALTER TABLE app.orders
  ADD COLUMN cancellation_reason text
    CHECK (
      cancellation_reason IS NULL
      OR char_length(cancellation_reason) BETWEEN 1 AND 300
    );
