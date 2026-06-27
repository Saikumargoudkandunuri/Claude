-- 046_customer_table.sql
-- Extract customer auth into a dedicated customers table.
-- A customer owns one or more projects via projects.customer_id FK.

-- Create the customers table
CREATE TABLE IF NOT EXISTS customers (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  mobile          TEXT NOT NULL UNIQUE,
  mobile_alt      TEXT,
  pin_hash        TEXT,
  pin_set         BOOLEAN NOT NULL DEFAULT false,
  last_login      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for mobile lookup (unique constraint already provides one, but explicit for clarity)
CREATE INDEX IF NOT EXISTS idx_customers_mobile ON customers(mobile);

-- Add customer_id FK to projects
ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_projects_customer_id
  ON projects(customer_id) WHERE customer_id IS NOT NULL;

-- Migrate existing data: create customer records from projects that have customer_mobile set
INSERT INTO customers (id, name, mobile, mobile_alt, pin_hash, pin_set, last_login)
SELECT
  gen_random_uuid(),
  COALESCE(customer_name, 'Customer'),
  customer_mobile,
  customer_mobile_alt,
  customer_pin_hash,
  customer_pin_set,
  customer_last_login
FROM projects
WHERE customer_mobile IS NOT NULL
  AND customer_mobile != ''
ON CONFLICT (mobile) DO NOTHING;

-- Link projects to their newly-created customer records
UPDATE projects p
SET customer_id = c.id
FROM customers c
WHERE p.customer_mobile = c.mobile
  AND p.customer_mobile IS NOT NULL;

-- Update customer_notifications FK: add customer_id column
ALTER TABLE customer_notifications
  ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE CASCADE;

-- Backfill customer_id on notifications from project's customer_id
UPDATE customer_notifications cn
SET customer_id = p.customer_id
FROM projects p
WHERE cn.project_id = p.id
  AND p.customer_id IS NOT NULL;

-- Update customer_messages FK: add customer_id column
ALTER TABLE customer_messages
  ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES customers(id) ON DELETE CASCADE;

-- Backfill customer_id on messages from project's customer_id
UPDATE customer_messages cm
SET customer_id = p.customer_id
FROM projects p
WHERE cm.project_id = p.id
  AND p.customer_id IS NOT NULL;
