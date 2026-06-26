-- 033 Photo timeline categories
ALTER TABLE files
  ADD COLUMN IF NOT EXISTS timeline_phase TEXT CHECK (
    timeline_phase IN ('before', 'during', 'after', NULL)
  ),
  ADD COLUMN IF NOT EXISTS taken_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_files_timeline ON files(project_id, timeline_phase, taken_at)
  WHERE category IN ('photo', 'video');
