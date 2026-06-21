-- 009 Triggers and indexes

-- Recompute payments.total_received from payment_history
CREATE OR REPLACE FUNCTION recompute_payment_total()
RETURNS TRIGGER AS $$
DECLARE
  pid uuid;
BEGIN
  pid := COALESCE(NEW.project_id, OLD.project_id);

  -- Ensure a payments summary row exists for the project
  INSERT INTO payments (project_id, quotation_amount, total_received)
  SELECT p.id, p.quotation_amount, 0
  FROM projects p
  WHERE p.id = pid
  ON CONFLICT (project_id) DO NOTHING;

  UPDATE payments
  SET total_received = COALESCE((
        SELECT SUM(amount) FROM payment_history WHERE project_id = pid
      ), 0),
      updated_at = now()
  WHERE project_id = pid;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_payment_history_aiud ON payment_history;
CREATE TRIGGER trg_payment_history_aiud
  AFTER INSERT OR UPDATE OR DELETE ON payment_history
  FOR EACH ROW EXECUTE FUNCTION recompute_payment_total();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

CREATE INDEX IF NOT EXISTS idx_projects_stage ON projects(current_stage);
CREATE INDEX IF NOT EXISTS idx_projects_supervisor ON projects(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_projects_designer ON projects(designer_id);

CREATE INDEX IF NOT EXISTS idx_files_project_category ON files(project_id, category);
CREATE INDEX IF NOT EXISTS idx_files_report ON files(report_id);

CREATE INDEX IF NOT EXISTS idx_reports_project_date ON daily_reports(project_id, report_date);
CREATE INDEX IF NOT EXISTS idx_reports_author ON daily_reports(author_id);

CREATE INDEX IF NOT EXISTS idx_assignments_user_active ON project_assignments(user_id, active);
CREATE INDEX IF NOT EXISTS idx_assignments_project ON project_assignments(project_id);

CREATE INDEX IF NOT EXISTS idx_workplans_project_date ON work_plans(project_id, plan_date);
CREATE INDEX IF NOT EXISTS idx_workplan_workers_user ON work_plan_workers(user_id);

CREATE INDEX IF NOT EXISTS idx_payment_history_project ON payment_history(project_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read);

CREATE INDEX IF NOT EXISTS idx_activity_project_time ON activity_logs(project_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_user_time ON activity_logs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_refresh_user ON refresh_tokens(user_id);
