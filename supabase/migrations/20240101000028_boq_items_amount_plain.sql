-- Migration 028: Convert boq_items.amount from GENERATED to plain column
--
-- The app explicitly inserts amount: item.amount (quantity * unit_rate
-- computed client-side). GENERATED ALWAYS rejects any explicit value,
-- so the column must be a regular DECIMAL instead.

ALTER TABLE boq_items DROP COLUMN IF EXISTS amount;

ALTER TABLE boq_items
  ADD COLUMN amount DECIMAL(15, 2);
