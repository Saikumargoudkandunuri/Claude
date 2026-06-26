-- 040_weekly_project_status.sql
-- Adds weekly health status tracking to projects.
-- ADDITIVE ONLY — does not touch any existing table.

CREATE TABLE IF NOT EXISTS project_weekly_status (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id    UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  status        VARCHAR(20) NOT NULL CHECK (status IN ('on_track', 'normal', 'slow')),
  notes         VARCHAR(200),
  set_by        UUID NOT NULL REFERENCES users(id),
  week_start    DATE NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (project_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_pws_project_week
  ON project_weekly_status(project_id, week_start DESC);

CREATE INDEX IF NOT EXISTS idx_pws_set_by
  ON project_weekly_status(set_by);
