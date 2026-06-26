-- 042 Geofence alerts: tracks when workers leave site and admin responses
CREATE TABLE IF NOT EXISTS geofence_alerts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  project_id      UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  attendance_id   UUID REFERENCES attendance_records(id) ON DELETE SET NULL,
  latitude        DOUBLE PRECISION NOT NULL,
  longitude       DOUBLE PRECISION NOT NULL,
  distance_meters INTEGER NOT NULL,
  status          VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, approved, declined, resolved
  admin_id        UUID REFERENCES users(id),
  resolved_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_geofence_alerts_user ON geofence_alerts(user_id, status);
CREATE INDEX IF NOT EXISTS idx_geofence_alerts_pending ON geofence_alerts(status) WHERE status = 'pending';
