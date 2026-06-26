-- 031 GPS coordinates on projects for geofence attendance
ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS site_latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS site_longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS site_radius_meters INTEGER DEFAULT 300;
