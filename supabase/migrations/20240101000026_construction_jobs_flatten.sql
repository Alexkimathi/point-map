-- Migration 026: Flatten construction_jobs to a standalone table
--
-- Mirrors migration 018 for survey_jobs. Fixes:
--   1. job_id NOT NULL + stale FK to jobs(id)
--   2. status ENUM (lowercase) → TEXT (capitalised)
--   3. progress_percent → adds progress_pct alias column
--   4. Missing columns: client_id, start_date, end_date, job_no,
--      is_archived, created_by, created_at
--   5. job_no auto-generation trigger (CT-YYYY-NNN)

-- ─── 1. DROP STALE FK AND NOT NULL ON job_id ─────────────────

ALTER TABLE construction_jobs DROP CONSTRAINT IF EXISTS construction_jobs_job_id_fkey;
ALTER TABLE construction_jobs ALTER COLUMN job_id DROP NOT NULL;

-- ─── 2. CONVERT status ENUM TO TEXT ──────────────────────────

ALTER TABLE construction_jobs ALTER COLUMN status DROP DEFAULT;
ALTER TABLE construction_jobs ALTER COLUMN status TYPE TEXT USING status::TEXT;

UPDATE construction_jobs SET status = CASE status
  WHEN 'ongoing'   THEN 'Ongoing'
  WHEN 'completed' THEN 'Completed'
  WHEN 'handover'  THEN 'Handover'
  WHEN 'tender'    THEN 'Tender'
  ELSE status
END;

ALTER TABLE construction_jobs ALTER COLUMN status SET DEFAULT 'Ongoing';

DROP TYPE IF EXISTS job_status_construction;

-- ─── 3. ADD MISSING COLUMNS ──────────────────────────────────

ALTER TABLE construction_jobs
  ADD COLUMN IF NOT EXISTS client_id   UUID         REFERENCES clients(id)  ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS start_date  DATE,
  ADD COLUMN IF NOT EXISTS end_date    DATE,
  ADD COLUMN IF NOT EXISTS progress_pct DECIMAL(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_archived BOOLEAN       DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS job_no      TEXT,
  ADD COLUMN IF NOT EXISTS created_by  UUID         REFERENCES profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_at  TIMESTAMPTZ   DEFAULT NOW();

-- ─── 4. JOB_NO AUTO-GENERATION TRIGGER ───────────────────────

CREATE OR REPLACE FUNCTION generate_construction_job_no()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  yr  TEXT    := TO_CHAR(NOW(), 'YYYY');
  seq INTEGER;
BEGIN
  SELECT COALESCE(
    MAX(CAST(SPLIT_PART(job_no, '-', 3) AS INTEGER)), 0
  ) + 1
  INTO seq
  FROM construction_jobs
  WHERE job_no LIKE 'CT-' || yr || '-%';

  NEW.job_no := 'CT-' || yr || '-' || LPAD(seq::TEXT, 3, '0');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_construction_job_no ON construction_jobs;
CREATE TRIGGER trg_construction_job_no
  BEFORE INSERT ON construction_jobs
  FOR EACH ROW
  WHEN (NEW.job_no IS NULL OR NEW.job_no = '')
  EXECUTE FUNCTION generate_construction_job_no();
