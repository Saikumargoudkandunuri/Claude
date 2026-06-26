-- 037 Worker performance scores
CREATE TABLE IF NOT EXISTS worker_performance_scores (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  score_month     DATE NOT NULL,
  reports_score   NUMERIC(5,2) DEFAULT 0,
  attendance_score NUMERIC(5,2) DEFAULT 0,
  tasks_score     NUMERIC(5,2) DEFAULT 0,
  total_score     NUMERIC(5,2) DEFAULT 0,
  computed_at     TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, score_month)
);

CREATE INDEX IF NOT EXISTS idx_performance_user ON worker_performance_scores(user_id, score_month);
