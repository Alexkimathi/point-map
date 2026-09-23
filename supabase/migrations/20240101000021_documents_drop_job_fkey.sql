-- Migration 021: Drop documents.job_id foreign key to jobs table
--
-- The app stores either a survey_jobs.id or construction_jobs.id in job_id
-- and uses job_type to distinguish them. The original FK to jobs(id) rejects
-- every insert because those IDs don't exist in the jobs parent table.

ALTER TABLE documents DROP CONSTRAINT IF EXISTS documents_job_id_fkey;
