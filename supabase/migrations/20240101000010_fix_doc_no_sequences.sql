-- ============================================================
-- Create finance_documents table (invoices + quotations unified)
-- ============================================================
CREATE TABLE IF NOT EXISTS finance_documents (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type         TEXT NOT NULL CHECK (type IN ('Invoice', 'Quotation')),
  doc_no       TEXT,
  client_id    UUID REFERENCES clients(id) ON DELETE SET NULL,
  job_type     TEXT,
  job_id       UUID,
  due_date     DATE,
  tax          NUMERIC DEFAULT 0,
  amount       NUMERIC DEFAULT 0,
  total        NUMERIC DEFAULT 0,
  line_items   JSONB,
  notes        TEXT,
  status       TEXT NOT NULL DEFAULT 'Draft',
  created_by   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_finance_documents_updated_at
  BEFORE UPDATE ON finance_documents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE finance_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "finance_documents_all" ON finance_documents
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ============================================================
-- Fix doc_no / lpo_no generation for finance_documents and lpos
--
-- Root cause: triggers used COUNT(*)+1 (breaks on deletion) and
-- were likely never applied to the live database. Also adds
-- advisory-locked RPC functions for atomic number generation
-- called directly from the app to avoid trigger dependency.
--
-- Safe to run multiple times (CREATE OR REPLACE / DROP IF EXISTS).
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Fix and recreate the BEFORE INSERT trigger function (safety net)
CREATE OR REPLACE FUNCTION finance_doc_set_doc_no()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_year    TEXT;
  v_prefix  TEXT;
  v_seq     INT;
  v_seq_col TEXT;
BEGIN
  v_year := TO_CHAR(now(), 'YYYY');

  IF NEW.type = 'Invoice' THEN
    v_prefix  := 'INV-' || v_year || '-';
    v_seq_col := 'Invoice';
  ELSE
    v_prefix  := 'QT-' || v_year || '-';
    v_seq_col := 'Quotation';
  END IF;

  SELECT COALESCE(
    MAX(CAST(SPLIT_PART(doc_no, '-', 3) AS INTEGER)), 0
  ) + 1
  INTO v_seq
  FROM finance_documents
  WHERE type = v_seq_col
    AND doc_no LIKE v_prefix || '%';

  NEW.doc_no := v_prefix || LPAD(v_seq::TEXT, 3, '0');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_finance_doc_no ON finance_documents;
CREATE TRIGGER trg_finance_doc_no
  BEFORE INSERT ON finance_documents
  FOR EACH ROW
  WHEN (NEW.doc_no IS NULL OR NEW.doc_no = '')
  EXECUTE FUNCTION finance_doc_set_doc_no();


-- 3. Advisory-locked RPC: generate next doc_no atomically
--    Called directly from the app — race-condition safe.
CREATE OR REPLACE FUNCTION generate_finance_doc_no(p_type TEXT)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_year   TEXT := TO_CHAR(now(), 'YYYY');
  v_prefix TEXT;
  v_seq    INT;
BEGIN
  -- Serialise concurrent calls for the same type + year
  PERFORM pg_advisory_xact_lock(hashtext('doc_no_' || p_type || v_year));

  IF p_type = 'Invoice' THEN
    v_prefix := 'INV-' || v_year || '-';
  ELSE
    v_prefix := 'QT-'  || v_year || '-';
  END IF;

  SELECT COALESCE(
    MAX(CAST(SPLIT_PART(doc_no, '-', 3) AS INTEGER)), 0
  ) + 1
  INTO v_seq
  FROM finance_documents
  WHERE type    = p_type
    AND doc_no LIKE v_prefix || '%';

  RETURN v_prefix || LPAD(v_seq::TEXT, 3, '0');
END;
$$;


-- 5. Clean up any stale empty-string doc_nos left from the broken trigger
--    ONLY deletes Draft documents with doc_no = '' — edit this if needed.
-- DELETE FROM finance_documents WHERE doc_no = '' AND status = 'Draft';
