CREATE TABLE app.customer_otp_challenges (
  id uuid PRIMARY KEY,
  phone_hash char(64) NOT NULL UNIQUE,
  otp_hash char(64) NOT NULL,
  expires_at timestamptz NOT NULL,
  attempt_count smallint NOT NULL DEFAULT 0
    CHECK (attempt_count BETWEEN 0 AND 5),
  provider_message_id text,
  delivery_accepted_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX customer_otp_challenges_expiry_idx
  ON app.customer_otp_challenges (expires_at);

CREATE TABLE app.customer_auth_rate_limits (
  scope text NOT NULL CHECK (scope IN ('phone', 'ip')),
  subject_hash char(64) NOT NULL,
  window_started_at timestamptz NOT NULL,
  request_count integer NOT NULL DEFAULT 0 CHECK (request_count >= 0),
  last_requested_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (scope, subject_hash)
);

CREATE INDEX customer_auth_rate_limits_updated_idx
  ON app.customer_auth_rate_limits (updated_at);
