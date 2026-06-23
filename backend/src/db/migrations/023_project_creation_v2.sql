-- 023 Project creation v2: default designer/supervisor; relax NOT NULL on phone

ALTER TABLE projects ADD COLUMN IF NOT EXISTS default_supervisor_id uuid REFERENCES users(id);
ALTER TABLE projects ADD COLUMN IF NOT EXISTS default_designer_id uuid REFERENCES users(id);

-- Project creation now only requires customer name; phone becomes optional.
ALTER TABLE projects ALTER COLUMN phone DROP NOT NULL;
