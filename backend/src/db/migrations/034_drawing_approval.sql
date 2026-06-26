-- 034 Drawing approval workflow
DO $$ BEGIN
  CREATE TYPE drawing_approval_status AS ENUM ('pending', 'approved', 'revision_requested');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE files
  ADD COLUMN IF NOT EXISTS approval_status drawing_approval_status DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS approval_note   TEXT,
  ADD COLUMN IF NOT EXISTS approved_by     UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS approved_at     TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS version_number  INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS parent_file_id  UUID REFERENCES files(id);
