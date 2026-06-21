-- 003 Projects, stage history, assignments
CREATE TABLE IF NOT EXISTS projects (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_number            text NOT NULL UNIQUE,
  customer_name             text NOT NULL,
  phone                     text NOT NULL,
  alt_phone                 text,
  address                   text,
  site_location             text,
  project_name              text NOT NULL,
  project_type              text,
  work_description          text,
  start_date                date,
  expected_completion_date  date,
  quotation_amount          numeric(14,2) NOT NULL DEFAULT 0,
  current_stage             project_stage NOT NULL DEFAULT 'discussion',
  supervisor_id             uuid REFERENCES users(id) ON DELETE SET NULL,
  designer_id               uuid REFERENCES users(id) ON DELETE SET NULL,
  remarks                   text,
  is_archived               boolean NOT NULL DEFAULT false,
  created_by                uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_projects_updated_at ON projects;
CREATE TRIGGER trg_projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS project_stage_history (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id  uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  stage       project_stage NOT NULL,
  status      stage_status NOT NULL DEFAULT 'in_progress',
  changed_by  uuid REFERENCES users(id) ON DELETE SET NULL,
  note        text,
  changed_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS project_assignments (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id   uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role         assignment_role NOT NULL,
  task         text,
  assigned_by  uuid REFERENCES users(id) ON DELETE SET NULL,
  active       boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (project_id, user_id, role)
);
