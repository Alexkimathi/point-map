-- Migration 030: Create lpos table
--
-- The lpos table was never included in any migration but is referenced
-- throughout the app (finance/lpos pages, reports, job profitability).

CREATE TABLE IF NOT EXISTS lpos (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lpo_no        TEXT        UNIQUE NOT NULL,
  supplier_name TEXT        NOT NULL,
  job_type      TEXT        CHECK (job_type IN ('survey', 'construction')),
  job_id        UUID,                          -- survey_jobs.id or construction_jobs.id
  items         JSONB       NOT NULL DEFAULT '[]',
  subtotal      NUMERIC     NOT NULL DEFAULT 0,
  tax           NUMERIC     NOT NULL DEFAULT 0,
  total         NUMERIC     NOT NULL DEFAULT 0,
  issued_date   DATE,
  notes         TEXT,
  status        TEXT        NOT NULL DEFAULT 'Draft',
  created_by    UUID        REFERENCES profiles(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_lpos_updated_at
  BEFORE UPDATE ON lpos
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE lpos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "lpos_all" ON lpos
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
