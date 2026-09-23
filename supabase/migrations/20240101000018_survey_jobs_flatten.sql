-- ============================================================
-- Migration 018: Flatten survey_jobs to a standalone table
--
-- The app treats survey_jobs as self-contained (no jobs parent row),
-- but the original schema used a jobs→survey_jobs parent/child pattern.
-- This migration:
--   1. Converts survey_type and status from ENUMs to TEXT so the app
--      can insert free-form values ('Topographic Survey', 'New', etc.)
--   2. Adds the columns the app expects: client_id, job_no, start_date,
--      end_date, equipment_ids, team_ids, is_archived, created_by, created_at
--   3. Creates the job_no auto-generation trigger
-- ============================================================

-- ─── 1. CONVERT ENUMS TO TEXT ────────────────────────────────

ALTER TABLE survey_jobs
  ALTER COLUMN survey_type TYPE TEXT USING survey_type::TEXT;

ALTER TABLE survey_jobs
  ALTER COLUMN status TYPE TEXT USING status::TEXT;

-- Update existing rows to match the app's capitalised status values
UPDATE survey_jobs SET status = CASE status
  WHEN 'new'         THEN 'New'
  WHEN 'in_progress' THEN 'In Progress'
  WHEN 'qa'          THEN 'QA'
  WHEN 'delivered'   THEN 'Delivered'
  WHEN 'paid'        THEN 'Paid'
  ELSE status
END;

ALTER TABLE survey_jobs ALTER COLUMN status SET DEFAULT 'New';

-- Safe to drop now that no columns reference them
DROP TYPE IF EXISTS survey_type;
DROP TYPE IF EXISTS job_status_survey;

-- ─── 2. ADD MISSING COLUMNS ──────────────────────────────────

ALTER TABLE survey_jobs
  ADD COLUMN IF NOT EXISTS client_id   UUID          REFERENCES clients(id)  ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS start_date  DATE,
  ADD COLUMN IF NOT EXISTS end_date    DATE,
  ADD COLUMN IF NOT EXISTS equipment_ids UUID[]       DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS team_ids    UUID[]         DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS is_archived BOOLEAN        DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS job_no      TEXT,
  ADD COLUMN IF NOT EXISTS created_by  UUID          REFERENCES profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS created_at  TIMESTAMPTZ    DEFAULT NOW();

-- ─── 3. JOB_NO AUTO-GENERATION TRIGGER ───────────────────────

CREATE OR REPLACE FUNCTION generate_survey_job_no()
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
  FROM survey_jobs
  WHERE job_no LIKE 'SV-' || yr || '-%';

  NEW.job_no := 'SV-' || yr || '-' || LPAD(seq::TEXT, 3, '0');
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_survey_job_no ON survey_jobs;
CREATE TRIGGER trg_survey_job_no
  BEFORE INSERT ON survey_jobs
  FOR EACH ROW
  WHEN (NEW.job_no IS NULL OR NEW.job_no = '')
  EXECUTE FUNCTION generate_survey_job_no();
