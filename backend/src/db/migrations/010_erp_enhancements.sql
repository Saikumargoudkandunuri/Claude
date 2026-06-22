-- 010 ERP enhancements: richer daily reports + worker task status

-- Daily reports: progress %, materials used (issues already captured in `problems`)
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS progress_percent int;
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS materials_used text;
ALTER TABLE daily_reports
  ADD CONSTRAINT daily_reports_progress_chk
  CHECK (progress_percent IS NULL OR (progress_percent >= 0 AND progress_percent <= 100))
  NOT VALID;

-- Worker task status on a work plan (assigned -> started -> completed)
DO $$ BEGIN
  CREATE TYPE task_status AS ENUM ('assigned','started','completed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE work_plan_workers ADD COLUMN IF NOT EXISTS status task_status NOT NULL DEFAULT 'assigned';
ALTER TABLE work_plan_workers ADD COLUMN IF NOT EXISTS started_at timestamptz;
ALTER TABLE work_plan_workers ADD COLUMN IF NOT EXISTS completed_at timestamptz;

-- Help the task panel queries
CREATE INDEX IF NOT EXISTS idx_wpw_status ON work_plan_workers(status);
