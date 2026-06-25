-- 028 Add PIN hash column for mobile+PIN authentication
ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_hash varchar(128);
