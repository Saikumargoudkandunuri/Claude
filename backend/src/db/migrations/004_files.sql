-- 004 Files (drawings, 3D, quotation, photos, videos, voice notes)
CREATE TABLE IF NOT EXISTS files (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id     uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  report_id      uuid,  -- optional link to a daily report (FK added in 005)
  category       file_category NOT NULL,
  original_name  text NOT NULL,
  storage_key    text NOT NULL,
  mime_type      text,
  size_bytes     bigint,
  caption        text,
  uploaded_by    uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
