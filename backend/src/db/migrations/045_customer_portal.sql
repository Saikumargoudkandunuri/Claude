-- 045_customer_portal.sql
-- Customer Portal: auth columns on projects + notifications + messages tables

-- Add customer auth columns to projects
ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS customer_mobile TEXT,
  ADD COLUMN IF NOT EXISTS customer_mobile_alt TEXT,
  ADD COLUMN IF NOT EXISTS customer_pin_hash TEXT,
  ADD COLUMN IF NOT EXISTS customer_pin_set BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS customer_last_login TIMESTAMPTZ;

-- Index for mobile lookup
CREATE INDEX IF NOT EXISTS idx_projects_customer_mobile
  ON projects(customer_mobile) WHERE customer_mobile IS NOT NULL;

-- Customer notifications table
CREATE TABLE IF NOT EXISTS customer_notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  is_read     BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customer_notifications_project
  ON customer_notifications(project_id, created_at DESC);

-- Customer messages (admin announcements) table
CREATE TABLE IF NOT EXISTS customer_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  posted_by   UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customer_messages_project
  ON customer_messages(project_id, created_at DESC);
