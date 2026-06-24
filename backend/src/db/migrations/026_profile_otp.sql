-- 026 Add OTP fields for password reset
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_otp varchar(6);
ALTER TABLE users ADD COLUMN IF NOT EXISTS reset_otp_expires timestamptz;
