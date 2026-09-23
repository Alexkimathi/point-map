-- Migration 029: Rename equipment and maintenance_logs columns to match app
--
-- equipment schema 000 → app column name
--   assigned_to       → assigned_to_user_id
--   calibration_due   → last_calibration_date
--   quantity          → stock_qty
--   min_stock_level   → min_stock_qty
--
-- maintenance_logs schema 000 → app column name
--   next_due          → next_due_date
--   done_by (UUID FK) → TEXT (app stores a free-form name, not a profile UUID)

-- ─── EQUIPMENT ────────────────────────────────────────────────

ALTER TABLE equipment RENAME COLUMN assigned_to       TO assigned_to_user_id;
ALTER TABLE equipment RENAME COLUMN calibration_due   TO last_calibration_date;
ALTER TABLE equipment RENAME COLUMN quantity          TO stock_qty;
ALTER TABLE equipment RENAME COLUMN min_stock_level   TO min_stock_qty;

-- ─── MAINTENANCE LOGS ─────────────────────────────────────────

ALTER TABLE maintenance_logs RENAME COLUMN next_due TO next_due_date;

-- done_by was a UUID FK to profiles; app stores a free-form name string
ALTER TABLE maintenance_logs DROP CONSTRAINT IF EXISTS maintenance_logs_done_by_fkey;
ALTER TABLE maintenance_logs ALTER COLUMN done_by TYPE TEXT USING done_by::TEXT;
