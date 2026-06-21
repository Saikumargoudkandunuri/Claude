-- 005 Daily reports and tomorrow work plans
CREATE TABLE IF NOT EXISTS daily_reports (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id        uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  author_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type              report_type NOT NULL,
  report_date       date NOT NULL DEFAULT current_date,
  work_done         text,
  pending_work      text,
  problems          text,
  materials_needed  text,
  tomorrow_notes    text,
  site_progress     text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (project_id, author_id, report_date, type)
);

-- Link files to reports (media attachments)
ALTER TABLE files
  DROP CONSTRAINT IF EXISTS files_report_id_fkey;
ALTER TABLE files
  ADD CONSTRAINT files_report_id_fkey
  FOREIGN KEY (report_id) REFERENCES daily_reports(id) ON DELETE CASCADE;

CREATE TABLE IF NOT EXISTS work_plans (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  plan_date   date NOT NULL,
  task        text,
  created_by  uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS work_plan_workers (
  work_plan_id  uuid NOT NULL REFERENCES work_plans(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (work_plan_id, user_id)
);
