-- Migration 020: Add missing columns to documents table
--
-- Migration 000 created documents with a different schema (type ENUM, no
-- category, no job_type). Migration 002's CREATE TABLE IF NOT EXISTS was
-- silently skipped because the table already existed.
-- This brings the live table in line with what the app expects.

-- Add job_type (which survey/construction job this document belongs to)
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS job_type TEXT CHECK (job_type IN ('survey', 'construction'));

-- Add category (replaces the old document_type ENUM 'type' column)
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'Other';

-- Convert the legacy 'type' ENUM column to TEXT so it no longer blocks inserts
-- (the app doesn't write to it, but keeping it as a strict ENUM can cause errors)
-- Must drop the column default first — it depends on the enum type.
ALTER TABLE documents ALTER COLUMN type DROP DEFAULT;
ALTER TABLE documents ALTER COLUMN type TYPE TEXT USING type::TEXT;
ALTER TABLE documents ALTER COLUMN type SET DEFAULT 'other';

DROP TYPE IF EXISTS document_type;
