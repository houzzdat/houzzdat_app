-- Sprint 3: Proof Gate Enforcement + Financial Foundation
-- Date: 2026-02-04

-- ============================================================
-- 1. Add requires_proof column to action_items
-- ============================================================
-- Default false; edge function sets true for action_required items.
-- Update category items never require proof.
ALTER TABLE public.action_items
  ADD COLUMN IF NOT EXISTS requires_proof boolean DEFAULT false;

-- Backfill existing action_required items to require proof
UPDATE public.action_items
  SET requires_proof = true
  WHERE category = 'action_required';

-- ============================================================
-- 2. DB trigger: prevent completion without proof
-- ============================================================
-- When requires_proof=true and proof_photo_url is null,
-- block transition to 'completed' status.
CREATE OR REPLACE FUNCTION enforce_proof_gate()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed'
     AND NEW.requires_proof = true
     AND (NEW.proof_photo_url IS NULL OR NEW.proof_photo_url = '')
     -- Allow completion via denial (manager_approval stays false)
     AND NEW.manager_approval IS DISTINCT FROM false
  THEN
    RAISE EXCEPTION 'Cannot complete action item: proof of work required but not uploaded';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_enforce_proof_gate ON public.action_items;
CREATE TRIGGER trigger_enforce_proof_gate
  BEFORE UPDATE ON public.action_items
  FOR EACH ROW
  WHEN (NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed')
  EXECUTE FUNCTION enforce_proof_gate();

-- ============================================================
-- 3. Create finance_transactions table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.finance_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id uuid NOT NULL REFERENCES public.projects(id),
  account_id uuid NOT NULL REFERENCES public.accounts(id),
  type text NOT NULL CHECK (type = ANY(ARRAY['purchase', 'labour_payment', 'petty_cash', 'other'])),
  amount numeric NOT NULL,
  currency text DEFAULT 'INR',
  item text,
  unit_price numeric,
  quantity numeric,
  unit text,
  vendor text,
  description text,
  voice_note_id uuid REFERENCES public.voice_notes(id),
  action_item_id uuid REFERENCES public.action_items(id),
  recorded_by uuid REFERENCES public.users(id),
  verified_by uuid REFERENCES public.users(id),
  verified_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now()
);

-- Index for project-level finance queries
CREATE INDEX IF NOT EXISTS idx_finance_transactions_project
  ON public.finance_transactions(project_id);

-- Index for account-level finance queries
CREATE INDEX IF NOT EXISTS idx_finance_transactions_account
  ON public.finance_transactions(account_id);

-- ============================================================
-- 4. RLS policies for finance_transactions
-- ============================================================
ALTER TABLE public.finance_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view finance transactions in their account"
  ON public.finance_transactions FOR SELECT
  USING (account_id IN (
    SELECT account_id FROM public.users WHERE id = auth.uid()
  ));

CREATE POLICY "Users can insert finance transactions in their account"
  ON public.finance_transactions FOR INSERT
  WITH CHECK (account_id IN (
    SELECT account_id FROM public.users WHERE id = auth.uid()
  ));
