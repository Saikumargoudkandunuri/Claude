-- Allow PIN-only registration (no password required)
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
