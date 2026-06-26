-- 032 Attendance / check-in records
DO $$ BEGIN
  CREATE TYPE location_type AS ENUM ('site', 'workshop', 'unknown');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS attendance_records (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  project_id      UUID REFERENCES projects(id) ON DELETE SET NULL,
  check_in_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  check_out_at    TIMESTAMPTZ,
  check_in_lat    DOUBLE PRECISION,
  check_in_lng    DOUBLE PRECISION,
  check_out_lat   DOUBLE PRECISION,
  check_out_lng   DOUBLE PRECISION,
  location_type   location_type NOT NULL DEFAULT 'unknown',
  is_within_geofence BOOLEAN DEFAULT false,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_attendance_user_date ON attendance_records(user_id, check_in_at);
CREATE INDEX IF NOT EXISTS idx_attendance_project ON attendance_records(project_id);
