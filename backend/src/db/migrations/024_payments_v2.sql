-- 024 Payments v2: payment mode + note + summary view

ALTER TABLE payment_history ADD COLUMN IF NOT EXISTS payment_mode text
  CHECK (payment_mode IS NULL OR payment_mode IN ('cash','bank_transfer','cheque','upi','other'));
ALTER TABLE payment_history ADD COLUMN IF NOT EXISTS note text;

-- Consistent balance + percentage view.
CREATE OR REPLACE VIEW payment_summary AS
  SELECT
    p.project_id,
    p.quotation_amount,
    p.total_received,
    (p.quotation_amount - p.total_received) AS balance_amount,
    CASE WHEN p.quotation_amount > 0
      THEN ROUND((p.total_received::numeric / p.quotation_amount) * 100, 1)
      ELSE 0
    END AS payment_percentage
  FROM payments p;
