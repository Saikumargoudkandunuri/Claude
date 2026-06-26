-- 042_snag_list.sql
-- Adds snag/punch list tracking for projects. ADDITIVE ONLY.

CREATE TABLE IF NOT EXISTS snag_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id      UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  title           VARCHAR(200) NOT NULL,
  description     VARCHAR(1000),
  status          VARCHAR(20) NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open', 'resolved', 'closed')),
  priority        VARCHAR(10) DEFAULT 'medium'
                  CHECK (priority IN ('low', 'medium', 'high')),
  assigned_to     UUID REFERENCES users(id),
  created_by      UUID NOT NULL REFERENCES users(id),
  resolved_by     UUID REFERENCES users(id),
  closed_by       UUID REFERENCES users(id),
  resolution_note VARCHAR(500),
  resolution_photo VARCHAR(500),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  resolved_at     TIMESTAMPTZ,
  closed_at       TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_snag_project_status
  ON snag_items(project_id, status);

CREATE INDEX IF NOT EXISTS idx_snag_assigned
  ON snag_items(assigned_to, status);
