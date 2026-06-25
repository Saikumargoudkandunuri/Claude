-- 029 Add avatar column for profile photos
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url text;
