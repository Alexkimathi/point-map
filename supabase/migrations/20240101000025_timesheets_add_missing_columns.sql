-- Migration 025: Bring timesheets in line with the app's schema
--
-- Migration 000 created timesheets with old column names (clock_in TIME,
-- clock_out TIME, hours_worked) and a FK to jobs(id). Migration 002 had
-- the correct schema but was skipped by CREATE TABLE IF NOT EXISTS.
-- This migration adds the missing columns and removes the stale FK.

-- Drop stale FK to the old jobs parent table
ALTER TABLE timesheets DROP CONSTRAINT IF EXISTS timesheets_job_id_fkey;

-- Add all columns the app expects
ALTER TABLE timesheets
  ADD COLUMN IF NOT EXISTS job_type       TEXT  CHECK (job_type IN ('survey', 'construction')),
  ADD COLUMN IF NOT EXISTS clock_in_time  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS clock_in_lat   FLOAT,
  ADD COLUMN IF NOT EXISTS clock_in_lng   FLOAT,
  ADD COLUMN IF NOT EXISTS clock_out_time TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS clock_out_lat  FLOAT,
  ADD COLUMN IF NOT EXISTS clock_out_lng  FLOAT,
  ADD COLUMN IF NOT EXISTS hours          FLOAT;
