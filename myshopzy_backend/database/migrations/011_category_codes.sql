ALTER TABLE app.categories
  ADD COLUMN category_code text
  CHECK (category_code IS NULL OR category_code ~ '^[a-z_]{1,40}$');

UPDATE app.categories
SET category_code = 'frozen_foods'
WHERE lower(name) LIKE '%frozen%'
   OR lower(slug) LIKE '%frozen%';
