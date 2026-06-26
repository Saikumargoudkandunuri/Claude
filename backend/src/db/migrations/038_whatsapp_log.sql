-- 038 WhatsApp summary log
CREATE TABLE IF NOT EXISTS whatsapp_summary_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sent_at     TIMESTAMPTZ DEFAULT now(),
  sent_to     TEXT NOT NULL,
  message     TEXT NOT NULL,
  status      TEXT DEFAULT 'sent',
  error       TEXT
);
