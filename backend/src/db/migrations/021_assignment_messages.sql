-- 021 Assignment messages (WhatsApp-style assignment briefs with daily expiry)

CREATE TABLE IF NOT EXISTS assignment_messages (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id      uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  assignment_id   uuid REFERENCES project_assignments(id) ON DELETE CASCADE,
  report_id       uuid REFERENCES daily_reports(id) ON DELETE SET NULL,
  author_id       uuid NOT NULL REFERENCES users(id),
  worker_id       uuid REFERENCES users(id),
  body            text,
  is_deleted      boolean DEFAULT false,
  valid_date      date NOT NULL,
  expires_at      timestamptz NOT NULL,
  created_at      timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_assignment_messages_assignment ON assignment_messages(assignment_id, valid_date);
CREATE INDEX IF NOT EXISTS idx_assignment_messages_project ON assignment_messages(project_id, valid_date);
CREATE INDEX IF NOT EXISTS idx_assignment_messages_worker ON assignment_messages(worker_id, valid_date);
