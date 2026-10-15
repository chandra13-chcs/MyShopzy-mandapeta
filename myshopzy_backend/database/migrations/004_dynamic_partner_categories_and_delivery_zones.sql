ALTER TABLE app.partners
  DROP CONSTRAINT partners_partner_type_check;

ALTER TABLE app.partners
  ADD CONSTRAINT partners_partner_type_format_check
  CHECK (partner_type ~ '^[a-z][a-z0-9_]{0,39}$');

ALTER TABLE app.partners
  ADD COLUMN is_active boolean
  GENERATED ALWAYS AS (status = 'approved') STORED;

CREATE INDEX partners_active_type_idx
  ON app.partners (partner_type)
  WHERE is_active = true;

CREATE TABLE app.serviceable_pincodes (
  pincode text PRIMARY KEY
    CHECK (pincode ~ '^[0-9]{6}$'),
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);
