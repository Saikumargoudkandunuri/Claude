-- 041_drawing_approval.sql
-- Adds approval workflow columns to files table. ADDITIVE ONLY.

ALTER TABLE files
ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20)
  DEFAULT 'approved'
  CHECK (approval_status IN ('pending', 'approved', 'revision_requested'));

ALTER TABLE files
ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES users(id);

ALTER TABLE files
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

ALTER TABLE files
ADD COLUMN IF NOT EXISTS revision_note VARCHAR(500);

CREATE INDEX IF NOT EXISTS idx_files_approval
  ON files(project_id, approval_status);

-- All existing files are already approved (DEFAULT handles this)
-- New uploads will also default to 'approved' for backward compatibility
-- Designers who want the approval gate will have it set to 'pending' via API later
