-- 006 Payments summary and history
CREATE TABLE IF NOT EXISTS payments (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id        uuid NOT NULL UNIQUE REFERENCES projects(id) ON DELETE CASCADE,
  quotation_amount  numeric(14,2) NOT NULL DEFAULT 0,
  total_received    numeric(14,2) NOT NULL DEFAULT 0,
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS payment_history (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id        uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  kind              payment_kind NOT NULL DEFAULT 'other',
  amount            numeric(14,2) NOT NULL CHECK (amount >= 0),
  paid_on           date NOT NULL DEFAULT current_date,
  method            text,
  reference_number  text,
  remarks           text,
  recorded_by       uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);
