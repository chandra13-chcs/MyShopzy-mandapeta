UPDATE app.partners
SET partner_type = CASE partner_type
  WHEN 'grocery' THEN 'local_store'
  WHEN 'other' THEN 'local_store'
  WHEN 'meat_shop' THEN 'meat'
  WHEN 'vegetables_fruits' THEN 'fruits_vegetables'
  ELSE partner_type
END
WHERE partner_type IN ('grocery', 'other', 'meat_shop', 'vegetables_fruits');

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM app.partners
    WHERE partner_type NOT IN (
      'restaurant', 'meat', 'bakery', 'fruits_vegetables', 'local_store'
    )
  ) THEN
    RAISE EXCEPTION 'Unsupported app.partners.partner_type values remain.';
  END IF;
END;
$$;

ALTER TABLE app.partners
  DROP CONSTRAINT IF EXISTS partners_partner_type_format_check;

ALTER TABLE app.partners
  ADD CONSTRAINT partners_partner_type_check
  CHECK (
    partner_type IN (
      'restaurant', 'meat', 'bakery', 'fruits_vegetables', 'local_store'
    )
  );
