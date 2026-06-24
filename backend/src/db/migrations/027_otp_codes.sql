-- 027 OTP authentication codes table
DROP TABLE IF EXISTS otp_codes;

CREATE TABLE otp_codes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone         varchar(20) NOT NULL,
  otp_hash      varchar(128) NOT NULL,
  purpose       varchar(20) NOT NULL DEFAULT 'login',
  attempts      int NOT NULL DEFAULT 0,
  max_attempts  int NOT NULL DEFAULT 3,
  expires_at    timestamptz NOT NULL,
  used          boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_codes_phone ON otp_codes (phone, purpose, used, expires_at);
