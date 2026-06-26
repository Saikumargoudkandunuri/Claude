-- 030 Login hardening + security-question based password reset
-- Additive only. Does not alter existing email/PIN login behaviour.

-- Login hardening + profile audit fields
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at       timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_changed_at timestamptz;
ALTER TABLE users ADD COLUMN IF NOT EXISTS login_attempts      int NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS locked_until        timestamptz;

-- Security questions for self-service "forgot password" (no OTP, no email).
-- answer_hash is a bcrypt hash of the lowercased, trimmed answer.
CREATE TABLE IF NOT EXISTS user_security_questions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  question    text NOT NULL,
  answer_hash text NOT NULL,
  set_at      timestamptz NOT NULL DEFAULT now()
);

-- One-time password reset tokens.
-- created_by NULL = self-service (security question); set = admin-issued.
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '1 hour'),
  used       boolean NOT NULL DEFAULT false,
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prt_user  ON password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_prt_token ON password_reset_tokens(token_hash);
