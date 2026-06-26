-- 036 Invoice and receipt generation log
DO $$ BEGIN
  CREATE TYPE invoice_type AS ENUM ('invoice', 'receipt', 'quotation_pdf');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS generated_documents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id      UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  payment_id      UUID,
  document_type   invoice_type NOT NULL,
  file_key        TEXT NOT NULL,
  generated_by    UUID REFERENCES users(id),
  created_at      TIMESTAMPTZ DEFAULT now()
);
