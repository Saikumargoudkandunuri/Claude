-- 008 Activity logs (audit trail)
CREATE TABLE IF NOT EXISTS activity_logs (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid REFERENCES users(id) ON DELETE SET NULL,
  project_id   uuid REFERENCES projects(id) ON DELETE CASCADE,
  action       text NOT NULL,
  entity_type  text,
  entity_id    uuid,
  description  text,
  metadata     jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);
