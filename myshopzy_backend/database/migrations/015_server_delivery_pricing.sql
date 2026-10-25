BEGIN;

ALTER TABLE app.orders
  ADD COLUMN delivery_distance_m integer,
  ADD COLUMN delivery_fee_kind text,
  ADD CONSTRAINT orders_delivery_distance_m_nonnegative_check
    CHECK (delivery_distance_m IS NULL OR delivery_distance_m >= 0),
  ADD CONSTRAINT orders_delivery_fee_kind_check
    CHECK (
      delivery_fee_kind IS NULL OR
      delivery_fee_kind IN ('standard', 'parcel')
    );

ALTER TABLE app.shops
  ADD COLUMN latitude numeric,
  ADD COLUMN longitude numeric;

UPDATE app.shops
SET latitude = CASE
      WHEN address->>'latitude' ~ '^-?[0-9]+(\.[0-9]+)?$'
        THEN (address->>'latitude')::numeric
      ELSE NULL
    END,
    longitude = CASE
      WHEN address->>'longitude' ~ '^-?[0-9]+(\.[0-9]+)?$'
        THEN (address->>'longitude')::numeric
      ELSE NULL
    END
WHERE address->>'latitude' ~ '^-?[0-9]+(\.[0-9]+)?$'
  AND address->>'longitude' ~ '^-?[0-9]+(\.[0-9]+)?$'
  AND CASE
    WHEN address->>'latitude' ~ '^-?[0-9]+(\.[0-9]+)?$'
      AND address->>'longitude' ~ '^-?[0-9]+(\.[0-9]+)?$'
    THEN (address->>'latitude')::numeric BETWEEN -90 AND 90
      AND (address->>'longitude')::numeric BETWEEN -180 AND 180
    ELSE false
  END;

ALTER TABLE app.shops
  ADD CONSTRAINT shops_latitude_range_check
    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  ADD CONSTRAINT shops_longitude_range_check
    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  ADD CONSTRAINT shops_coordinates_pair_check
    CHECK ((latitude IS NULL) = (longitude IS NULL));

ALTER TABLE app.parcel_bookings
  ADD COLUMN pickup_latitude numeric,
  ADD COLUMN pickup_longitude numeric,
  ADD COLUMN drop_latitude numeric,
  ADD COLUMN drop_longitude numeric,
  ADD COLUMN delivery_distance_m integer,
  ADD COLUMN delivery_fee_minor bigint,
  ADD COLUMN delivery_fee_kind text,
  ADD CONSTRAINT parcel_pickup_latitude_range_check
    CHECK (pickup_latitude IS NULL OR pickup_latitude BETWEEN -90 AND 90),
  ADD CONSTRAINT parcel_pickup_longitude_range_check
    CHECK (pickup_longitude IS NULL OR pickup_longitude BETWEEN -180 AND 180),
  ADD CONSTRAINT parcel_drop_latitude_range_check
    CHECK (drop_latitude IS NULL OR drop_latitude BETWEEN -90 AND 90),
  ADD CONSTRAINT parcel_drop_longitude_range_check
    CHECK (drop_longitude IS NULL OR drop_longitude BETWEEN -180 AND 180),
  ADD CONSTRAINT parcel_pickup_coordinates_pair_check
    CHECK ((pickup_latitude IS NULL) = (pickup_longitude IS NULL)),
  ADD CONSTRAINT parcel_drop_coordinates_pair_check
    CHECK ((drop_latitude IS NULL) = (drop_longitude IS NULL)),
  ADD CONSTRAINT parcel_delivery_distance_m_nonnegative_check
    CHECK (delivery_distance_m IS NULL OR delivery_distance_m >= 0),
  ADD CONSTRAINT parcel_delivery_fee_minor_nonnegative_check
    CHECK (delivery_fee_minor IS NULL OR delivery_fee_minor >= 0),
  ADD CONSTRAINT parcel_delivery_fee_kind_check
    CHECK (
      delivery_fee_kind IS NULL OR delivery_fee_kind = 'parcel'
    );

COMMIT;
