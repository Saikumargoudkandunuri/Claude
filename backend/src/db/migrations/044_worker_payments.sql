-- 044_worker_payments.sql
-- Adds worker payment/payroll records. ADDITIVE ONLY.

CREATE TABLE IF NOT EXISTS worker_payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  payment_type    VARCHAR(20) NOT NULL
                  CHECK (payment_type IN ('salary', 'advance', 'bonus')),
  amount          NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  month_year      VARCHAR(7) NOT NULL,
  days_present    INT,
  days_workshop   INT,
  days_absent     INT,
  daily_rate      NUMERIC(8,2),
  gross_earned    NUMERIC(10,2),
  total_advances  NUMERIC(10,2) DEFAULT 0,
  total_bonuses   NUMERIC(10,2) DEFAULT 0,
  net_payable     NUMERIC(10,2),
  proof_image_url VARCHAR(500),
  notes           VARCHAR(300),
  paid_by         UUID NOT NULL REFERENCES users(id),
  paid_at         TIMESTAMPTZ DEFAULT NOW(),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wp_user_month
  ON worker_payments(user_id, month_year DESC);

CREATE INDEX IF NOT EXISTS idx_wp_month
  ON worker_payments(month_year DESC);
