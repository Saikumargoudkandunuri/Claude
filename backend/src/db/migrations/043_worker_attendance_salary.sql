-- 043_worker_attendance_salary.sql
-- Adds worker attendance tracking and salary profile columns. ADDITIVE ONLY.

-- Add salary fields to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS monthly_salary NUMERIC(10,2) DEFAULT 0;

ALTER TABLE users
ADD COLUMN IF NOT EXISTS working_days_per_month INT DEFAULT 26;

-- Worker attendance table — one row per worker per day
CREATE TABLE IF NOT EXISTS worker_attendance (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date            DATE NOT NULL DEFAULT CURRENT_DATE,
  work_mode       VARCHAR(20) NOT NULL
                  CHECK (work_mode IN ('at_site', 'workshop', 'leave', 'absent')),
  project_id      UUID REFERENCES projects(id) ON DELETE SET NULL,
  check_in_time   TIMESTAMPTZ,
  check_out_time  TIMESTAMPTZ,
  hours_worked    NUMERIC(4,2),
  notes           VARCHAR(200),
  marked_by       UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_wa_user_date
  ON worker_attendance(user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_wa_date
  ON worker_attendance(date DESC);

CREATE INDEX IF NOT EXISTS idx_wa_project
  ON worker_attendance(project_id, date DESC);
