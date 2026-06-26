-- 035 Project timeline / planned dates per stage
CREATE TABLE IF NOT EXISTS project_stage_plans (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id    UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  stage         TEXT NOT NULL,
  planned_start DATE,
  planned_end   DATE,
  actual_start  DATE,
  actual_end    DATE,
  set_by        UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(project_id, stage)
);

CREATE INDEX IF NOT EXISTS idx_stage_plans_project ON project_stage_plans(project_id);
