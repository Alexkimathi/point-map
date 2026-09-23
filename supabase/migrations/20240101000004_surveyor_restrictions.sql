-- ============================================================
-- SURVEYOR ACCESS RESTRICTIONS
-- Run in Supabase Dashboard → SQL Editor
-- ============================================================

-- Helper: returns the current user's role as text
-- (CREATE OR REPLACE is safe to re-run)
DROP FUNCTION IF EXISTS get_user_role() CASCADE;
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role::text FROM profiles WHERE id = auth.uid();
$$;

-- ── 1. Survey jobs: surveyors see only their assigned jobs ───
DROP POLICY IF EXISTS "survey_jobs_select" ON survey_jobs;

CREATE POLICY "survey_jobs_select" ON survey_jobs
FOR SELECT TO authenticated
USING (
  CASE get_user_role()
    WHEN 'surveyor' THEN
      id IN (
        SELECT job_id FROM job_team
        WHERE user_id = auth.uid()
      )
    ELSE true
  END
);

-- ── 2. Expenses: surveyors cannot read cost data ─────────────
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "expenses_select" ON expenses;
DROP POLICY IF EXISTS "expenses_insert" ON expenses;
DROP POLICY IF EXISTS "expenses_update" ON expenses;
DROP POLICY IF EXISTS "expenses_delete" ON expenses;

CREATE POLICY "expenses_select" ON expenses
FOR SELECT TO authenticated
USING (get_user_role() IN ('admin', 'manager', 'accountant', 'site_engineer'));

CREATE POLICY "expenses_insert" ON expenses
FOR INSERT TO authenticated
WITH CHECK (get_user_role() IN ('admin', 'manager', 'accountant'));

CREATE POLICY "expenses_update" ON expenses
FOR UPDATE TO authenticated
USING (get_user_role() IN ('admin', 'manager', 'accountant'));

CREATE POLICY "expenses_delete" ON expenses
FOR DELETE TO authenticated
USING (get_user_role() IN ('admin', 'manager', 'accountant'));

