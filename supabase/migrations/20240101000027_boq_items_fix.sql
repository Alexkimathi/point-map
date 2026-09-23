-- Migration 027: Fix boq_items schema to match the app
--
-- Problems in migration 000:
--   1. job_id NOT NULL FK to jobs(id) — app passes construction_jobs IDs
--   2. No job_type column
--   3. Column named 'rate'; app inserts/selects 'unit_rate'
--   4. GENERATED amount column uses 'rate', must be rebuilt after rename

-- ─── 1. DROP STALE FK AND NOT NULL ───────────────────────────

ALTER TABLE boq_items DROP CONSTRAINT IF EXISTS boq_items_job_id_fkey;
ALTER TABLE boq_items ALTER COLUMN job_id DROP NOT NULL;

-- ─── 2. ADD job_type ─────────────────────────────────────────

ALTER TABLE boq_items
  ADD COLUMN IF NOT EXISTS job_type TEXT CHECK (job_type IN ('survey', 'construction'));

-- ─── 3. RENAME rate → unit_rate AND REBUILD generated amount ─

-- Must drop the generated column first (it references 'rate')
ALTER TABLE boq_items DROP COLUMN IF EXISTS amount;

ALTER TABLE boq_items RENAME COLUMN rate TO unit_rate;

ALTER TABLE boq_items
  ADD COLUMN amount DECIMAL(15, 2)
    GENERATED ALWAYS AS (COALESCE(quantity, 0) * COALESCE(unit_rate, 0)) STORED;
