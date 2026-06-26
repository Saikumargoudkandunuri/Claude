-- 039 Localisation preference
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS preferred_language TEXT DEFAULT 'en'
    CHECK (preferred_language IN ('en', 'te', 'hi'));
