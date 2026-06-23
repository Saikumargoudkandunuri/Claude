-- 022 Report enhancements: designer reports, assignment briefs, read receipts

-- New report types: designer reports + auto-generated assignment briefs.
ALTER TYPE report_type ADD VALUE IF NOT EXISTS 'designer';
ALTER TYPE report_type ADD VALUE IF NOT EXISTS 'assignment_brief';

ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS is_assignment_brief boolean DEFAULT false;
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS assignment_id uuid REFERENCES project_assignments(id);
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS read_by jsonb DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_daily_reports_assignment
  ON daily_reports(assignment_id) WHERE assignment_id IS NOT NULL;
