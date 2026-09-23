-- Migration 024: Add job_type to expenses and drop stale jobs FK
--
-- The app inserts job_type ('survey'|'construction') and a survey_jobs/
-- construction_jobs ID into job_id. The original FK to jobs(id) rejects
-- those inserts, and job_type column was never added.

ALTER TABLE expenses DROP CONSTRAINT IF EXISTS expenses_job_id_fkey;

ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS job_type TEXT CHECK (job_type IN ('survey', 'construction'));
