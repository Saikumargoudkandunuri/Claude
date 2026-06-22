-- 011 Drawing categories simplification + chat-style reports

-- New file categories.
ALTER TYPE file_category ADD VALUE IF NOT EXISTS '2d_drawing';
ALTER TYPE file_category ADD VALUE IF NOT EXISTS 'document';
ALTER TYPE file_category ADD VALUE IF NOT EXISTS 'site_measurement';

-- Allow multiple report entries per worker/day so reports behave like a
-- WhatsApp-style message timeline (drop the one-per-day unique constraint).
DO $$
DECLARE c text;
BEGIN
  SELECT conname INTO c
    FROM pg_constraint
   WHERE conrelid = 'daily_reports'::regclass AND contype = 'u'
   LIMIT 1;
  IF c IS NOT NULL THEN
    EXECUTE format('ALTER TABLE daily_reports DROP CONSTRAINT %I', c);
  END IF;
END $$;
