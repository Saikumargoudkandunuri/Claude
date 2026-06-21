-- 001 Extensions and enum types
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;     -- case-insensitive email

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('admin','supervisor','designer','worker');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE user_status AS ENUM ('pending','approved','rejected','disabled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE worker_status AS ENUM ('workshop','at_site','leave','holiday');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE project_stage AS ENUM (
    'discussion','3d_design','drawing','material_purchase','cutting','making',
    'lamination','painting','packing','transport','installation','checking','completed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE file_category AS ENUM (
    'working_drawing','measurement_drawing','site_drawing','pdf_drawing',
    '3d_design','quotation','photo','video','voice_note'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE report_type AS ENUM ('worker','supervisor');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE payment_kind AS ENUM ('advance','second','third','final','other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE assignment_role AS ENUM ('supervisor','designer','worker');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE stage_status AS ENUM ('pending','in_progress','completed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Shared trigger function to maintain updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
