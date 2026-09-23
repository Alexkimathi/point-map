-- Migration 023: Re-point payments.invoice_id to finance_documents
--
-- The app moved from the old invoices table to finance_documents, but
-- the payments table still has a FK referencing invoices(id), which
-- rejects every insert since the IDs come from finance_documents.

ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_invoice_id_fkey;

ALTER TABLE payments
  ADD CONSTRAINT payments_finance_document_id_fkey
  FOREIGN KEY (invoice_id) REFERENCES finance_documents(id) ON DELETE CASCADE;
