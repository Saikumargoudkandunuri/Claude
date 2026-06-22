-- 012 Master Rectification: bug fixes + new feature tables
-- Covers: FIX-01 through FIX-12, FEATURE-01 through FEATURE-14

-- ============================================================
-- FIX-01: Payment trigger — make it DB-only (already correct in 009)
-- Ensure UPDATE coverage (already handles INSERT/UPDATE/DELETE in 009)
-- Re-create for safety with improved NULL handling
-- ============================================================
CREATE OR REPLACE FUNCTION recompute_payment_total()
RETURNS TRIGGER AS $$
DECLARE
  pid uuid;
BEGIN
  pid := COALESCE(NEW.project_id, OLD.project_id);
  INSERT INTO payments (project_id, quotation_amount, total_received)
  SELECT p.id, p.quotation_amount, 0
  FROM projects p WHERE p.id = pid
  ON CONFLICT (project_id) DO NOTHING;

  UPDATE payments
  SET total_received = COALESCE(
        (SELECT SUM(amount) FROM payment_history WHERE project_id = pid), 0
      ),
      updated_at = now()
  WHERE project_id = pid;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_payment_history_aiud ON payment_history;
CREATE TRIGGER trg_payment_history_aiud
  AFTER INSERT OR UPDATE OR DELETE ON payment_history
  FOR EACH ROW EXECUTE FUNCTION recompute_payment_total();

-- ============================================================
-- FIX-02: Latest-only drawing — partial unique index
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS uq_latest_file
  ON files (project_id, category)
  WHERE category IN (
    'working_drawing','measurement_drawing','site_drawing',
    'pdf_drawing','3d_design','quotation','2d_drawing','site_measurement'
  );

-- ============================================================
-- FIX-04: Work plans — ensure ON DELETE CASCADE
-- ============================================================
ALTER TABLE work_plans
  DROP CONSTRAINT IF EXISTS work_plans_project_id_fkey;
ALTER TABLE work_plans
  ADD CONSTRAINT work_plans_project_id_fkey
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE;

ALTER TABLE work_plan_workers
  DROP CONSTRAINT IF EXISTS work_plan_workers_work_plan_id_fkey;
ALTER TABLE work_plan_workers
  ADD CONSTRAINT work_plan_workers_work_plan_id_fkey
  FOREIGN KEY (work_plan_id) REFERENCES work_plans(id) ON DELETE CASCADE;

-- ============================================================
-- FIX-10: Archive instead of delete — add archived_at column
-- ============================================================
ALTER TABLE projects ADD COLUMN IF NOT EXISTS archived_at timestamptz;

-- ============================================================
-- FEATURE-01: Daily Report Deadline & Missed Report Tracker
-- ============================================================
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS submitted_at timestamptz DEFAULT now();
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS gps_latitude numeric(10,7);
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS gps_longitude numeric(10,7);
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS gps_accuracy numeric(6,2);
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS gps_captured_at timestamptz;

CREATE TABLE IF NOT EXISTS missed_reports (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id   uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  report_date  date NOT NULL,
  notified_at  timestamptz,
  created_at   timestamptz DEFAULT now(),
  UNIQUE(project_id, user_id, report_date)
);
CREATE INDEX IF NOT EXISTS idx_missed_reports_date ON missed_reports(report_date, notified_at);

-- ============================================================
-- FEATURE-02: Stage Approval Gate
-- ============================================================
ALTER TABLE project_stage_history ADD COLUMN IF NOT EXISTS requires_approval boolean DEFAULT false;
ALTER TABLE project_stage_history ADD COLUMN IF NOT EXISTS approved_by uuid REFERENCES users(id);
ALTER TABLE project_stage_history ADD COLUMN IF NOT EXISTS approved_at timestamptz;
ALTER TABLE project_stage_history ADD COLUMN IF NOT EXISTS approval_note text;

-- ============================================================
-- FEATURE-03: Material & Item Checklist per Stage
-- ============================================================
DO $$ BEGIN
  CREATE TYPE checklist_status AS ENUM ('pending','ordered','received','not_needed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS material_checklists (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id   uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  stage        project_stage NOT NULL,
  item_name    text NOT NULL,
  quantity     text,
  unit         text,
  status       checklist_status NOT NULL DEFAULT 'pending',
  notes        text,
  created_by   uuid REFERENCES users(id),
  updated_by   uuid REFERENCES users(id),
  created_at   timestamptz DEFAULT now(),
  updated_at   timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_checklists_project_stage ON material_checklists(project_id, stage, status);

-- ============================================================
-- FEATURE-04: Expense Tracking
-- ============================================================
DO $$ BEGIN
  CREATE TYPE expense_category AS ENUM ('material','labour','transport','equipment','other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS expenses (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  stage       project_stage,
  category    expense_category NOT NULL DEFAULT 'material',
  description text NOT NULL,
  amount      numeric(14,2) NOT NULL CHECK (amount > 0),
  spent_on    date NOT NULL DEFAULT CURRENT_DATE,
  receipt_key text,
  recorded_by uuid REFERENCES users(id),
  created_at  timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_expenses_project_date ON expenses(project_id, spent_on);
CREATE INDEX IF NOT EXISTS idx_expenses_project_stage ON expenses(project_id, stage);

-- ============================================================
-- FEATURE-05: Project-level Chat / Discussion Thread
-- ============================================================
CREATE TABLE IF NOT EXISTS project_messages (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id     uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  author_id      uuid NOT NULL REFERENCES users(id),
  body           text NOT NULL CHECK (char_length(body) <= 2000),
  attachment_key text,
  is_deleted     boolean DEFAULT false,
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_messages_project_time ON project_messages(project_id, created_at DESC);

-- ============================================================
-- FEATURE-06: OTP / Phone-based Login
-- ============================================================
CREATE TABLE IF NOT EXISTS otp_codes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       text NOT NULL,
  code_hash   text NOT NULL,
  expires_at  timestamptz NOT NULL,
  used        boolean DEFAULT false,
  created_at  timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_otp_phone_expires ON otp_codes(phone, expires_at);

-- ============================================================
-- FEATURE-07: Client Read-Only Progress Portal
-- ============================================================
CREATE TABLE IF NOT EXISTS client_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  uuid NOT NULL UNIQUE REFERENCES projects(id) ON DELETE CASCADE,
  token       text NOT NULL UNIQUE,
  enabled     boolean DEFAULT true,
  created_by  uuid REFERENCES users(id),
  created_at  timestamptz DEFAULT now()
);

-- ============================================================
-- FEATURE-10: Worker Attendance / Status History
-- ============================================================
CREATE TABLE IF NOT EXISTS worker_status_history (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  old_status  worker_status,
  new_status  worker_status NOT NULL,
  changed_by  uuid REFERENCES users(id),
  changed_at  timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_worker_status_history_user ON worker_status_history(user_id, changed_at DESC);

-- Trigger to auto-log worker status changes
CREATE OR REPLACE FUNCTION log_worker_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.worker_status IS DISTINCT FROM NEW.worker_status THEN
    INSERT INTO worker_status_history (user_id, old_status, new_status, changed_by, changed_at)
    VALUES (NEW.id, OLD.worker_status, NEW.worker_status, NEW.id, now());
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_worker_status ON users;
CREATE TRIGGER trg_worker_status
  AFTER UPDATE OF worker_status ON users
  FOR EACH ROW EXECUTE FUNCTION log_worker_status_change();

-- ============================================================
-- FEATURE-14: Activity Log Archival
-- ============================================================
CREATE TABLE IF NOT EXISTS activity_logs_archive (LIKE activity_logs INCLUDING ALL);
