-- 025 Allow multiple files per drawing category (BUG-01)
-- Drawings (2D / Working / 3D), photos, videos, voice notes, documents may have
-- many files. Only 'quotation' keeps a single active file.

DROP INDEX IF EXISTS uq_latest_file;

CREATE UNIQUE INDEX IF NOT EXISTS uq_latest_quotation
  ON files (project_id, category)
  WHERE category = 'quotation';
