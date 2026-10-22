ALTER TABLE app.partners
  ADD COLUMN commission_bps_override integer
  CHECK (commission_bps_override BETWEEN 0 AND 10000);

ALTER TABLE app.categories
  ADD COLUMN commission_bps_override integer
  CHECK (commission_bps_override BETWEEN 0 AND 10000);

ALTER TABLE app.order_items
  ADD COLUMN commission_bps integer NOT NULL DEFAULT 0
  CHECK (commission_bps >= 0),
  ADD COLUMN commission_minor bigint NOT NULL DEFAULT 0
  CHECK (commission_minor >= 0);

ALTER TABLE app.orders
  ADD COLUMN commission_minor bigint NOT NULL DEFAULT 0
  CHECK (commission_minor >= 0);