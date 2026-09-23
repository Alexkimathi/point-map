-- Migration 019: Make survey_jobs.job_id nullable
--
-- The app inserts into survey_jobs directly without creating a parent
-- jobs row, so the NOT NULL constraint on job_id prevents every insert.
-- The jobs→survey_jobs parent/child pattern is no longer used.

ALTER TABLE survey_jobs ALTER COLUMN job_id DROP NOT NULL;
