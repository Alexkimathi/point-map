-- Migration 022: Convert payments.method from ENUM to TEXT
--
-- The app sends capitalised values ('Cash', 'Bank Transfer', 'M-Pesa',
-- 'Cheque', 'Other') but the payment_method ENUM uses lowercase/underscore
-- variants ('cash', 'bank_transfer', 'mpesa', 'cheque', 'other').

ALTER TABLE payments ALTER COLUMN method DROP DEFAULT;
ALTER TABLE payments ALTER COLUMN method TYPE TEXT USING method::TEXT;

-- Normalise existing rows to the capitalised values the app expects
UPDATE payments SET method = CASE method
  WHEN 'cash'          THEN 'Cash'
  WHEN 'bank_transfer' THEN 'Bank Transfer'
  WHEN 'mpesa'         THEN 'M-Pesa'
  WHEN 'cheque'        THEN 'Cheque'
  WHEN 'other'         THEN 'Other'
  ELSE method
END;

ALTER TABLE payments ALTER COLUMN method SET DEFAULT 'Bank Transfer';

DROP TYPE IF EXISTS payment_method;
