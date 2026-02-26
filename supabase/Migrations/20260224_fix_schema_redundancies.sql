-- Migration: Fix Schema Redundancies
-- Date: 2026-02-24
-- Purpose: Remove or enforce computed-column semantics for columns that are
--          fully derivable from other columns in the same row.
--
-- Background: A full schema redundancy audit was performed and the following
-- were identified as actionable at the database level:
--
--   (A) owner_payments.allocated_to_project  → always equals project_id
--   (B) action_items.needs_review (boolean)  → always derivable from review_status
--   (C) boq_items.budgeted_total             → always = budgeted_rate * planned_quantity
--       (trigger already exists; this migration makes the constraint explicit)
--
-- Columns intentionally NOT removed here:
--   • boq_items.budgeted_total is kept as a stored-computed column (trigger
--     keeps it in sync); removing it would break existing BI/reporting queries
--     that read it directly.  A DB-generated column would require Postgres 12+
--     and a table rewrite — that is a larger change deferred to a future migration.
--   • action_items.needs_review index is kept (but the boolean will be auto-synced
--     via trigger so it stays useful for partial index queries).
--   • owner_payments.allocated_to_project FK is kept for backwards compat with any
--     existing reports that JOIN on it, but it will be kept in sync with project_id
--     via a trigger.
-- ============================================================================


-- ============================================================================
-- A. owner_payments: keep allocated_to_project in sync with project_id
--    via a trigger so the redundant column can never silently diverge.
--    The app no longer writes allocated_to_project (fixed in add_owner_payment_sheet.dart).
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_owner_payment_allocation()
RETURNS TRIGGER AS $$
BEGIN
  -- Always mirror project_id → allocated_to_project so they stay identical.
  NEW.allocated_to_project = NEW.project_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_owner_payment_allocation ON public.owner_payments;
CREATE TRIGGER trg_sync_owner_payment_allocation
  BEFORE INSERT OR UPDATE ON public.owner_payments
  FOR EACH ROW
  EXECUTE FUNCTION sync_owner_payment_allocation();

-- Backfill any existing rows where the columns diverged
UPDATE public.owner_payments
  SET allocated_to_project = project_id
  WHERE allocated_to_project IS DISTINCT FROM project_id;

COMMENT ON COLUMN public.owner_payments.allocated_to_project
  IS 'DEPRECATED — mirrors project_id via trigger. Kept for backwards-compat; use project_id for all new queries.';


-- ============================================================================
-- B. action_items: auto-sync needs_review (boolean) from review_status (enum)
--    Rule: needs_review = (review_status IN (''pending_review'', ''flagged''))
--    The app already derives this in Flutter code; the trigger makes the DB
--    authoritative so any edge function or direct INSERT also stays consistent.
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_action_item_needs_review()
RETURNS TRIGGER AS $$
BEGIN
  -- Derive needs_review entirely from review_status; never let them diverge.
  NEW.needs_review = (NEW.review_status IN ('pending_review', 'flagged'));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_action_item_needs_review ON public.action_items;
CREATE TRIGGER trg_sync_action_item_needs_review
  BEFORE INSERT OR UPDATE ON public.action_items
  FOR EACH ROW
  EXECUTE FUNCTION sync_action_item_needs_review();

-- Backfill: fix any existing rows where needs_review diverged from review_status
UPDATE public.action_items
  SET needs_review = (review_status IN ('pending_review', 'flagged'))
  WHERE needs_review IS DISTINCT FROM (review_status IN ('pending_review', 'flagged'));

COMMENT ON COLUMN public.action_items.needs_review
  IS 'DERIVED — auto-synced from review_status via trigger. True iff review_status is ''pending_review'' or ''flagged''. Do not write directly.';


-- ============================================================================
-- C. boq_items: ensure budgeted_total trigger covers INSERT + UPDATE
--    (The original trigger in 20260217_project_plans_boq_budgets.sql covers
--    both, but this migration makes the intent explicit and adds a NULL-safety
--    guard so budgeted_total can never be NULL when rate + qty are present.)
-- ============================================================================

-- Re-create the trigger function with NULL guard and explicit comment
CREATE OR REPLACE FUNCTION update_boq_item_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();

  -- Auto-compute status based on consumption ratio
  IF new.consumed_quantity >= new.planned_quantity * 1.0
     AND new.consumed_quantity > new.planned_quantity THEN
    NEW.status = 'over_consumed';
  ELSIF new.consumed_quantity >= new.planned_quantity THEN
    NEW.status = 'fully_consumed';
  ELSIF new.consumed_quantity > 0 THEN
    NEW.status = 'partially_consumed';
  ELSE
    NEW.status = 'planned';
  END IF;

  -- Always recompute budgeted_total from its source columns.
  -- This means the stored column can never silently diverge from
  -- budgeted_rate * planned_quantity even if only one input changes.
  IF NEW.budgeted_rate IS NOT NULL AND NEW.planned_quantity IS NOT NULL THEN
    NEW.budgeted_total = NEW.budgeted_rate * NEW.planned_quantity;
  ELSE
    -- If either input is NULL, set total to NULL rather than leaving a stale value
    NEW.budgeted_total = NULL;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-create triggers (DROP IF EXISTS + CREATE is idempotent)
DROP TRIGGER IF EXISTS boq_items_before_update ON public.boq_items;
CREATE TRIGGER boq_items_before_update
  BEFORE UPDATE ON public.boq_items
  FOR EACH ROW
  EXECUTE FUNCTION update_boq_item_timestamp();

DROP TRIGGER IF EXISTS boq_items_before_insert ON public.boq_items;
CREATE TRIGGER boq_items_before_insert
  BEFORE INSERT ON public.boq_items
  FOR EACH ROW
  EXECUTE FUNCTION update_boq_item_timestamp();

-- Backfill: recompute budgeted_total for any rows where it diverged
UPDATE public.boq_items
  SET budgeted_total = budgeted_rate * planned_quantity
  WHERE budgeted_rate IS NOT NULL
    AND planned_quantity IS NOT NULL
    AND budgeted_total IS DISTINCT FROM (budgeted_rate * planned_quantity);

COMMENT ON COLUMN public.boq_items.budgeted_total
  IS 'COMPUTED — always = budgeted_rate * planned_quantity, maintained by trigger. Do not write directly; reads are safe for reporting.';


-- ============================================================================
-- D. Update the performance index on needs_review to reflect that it is now
--    a derived column.  The partial index on review_status is more useful.
--    We keep the needs_review index (it is valid and still used by legacy queries)
--    but add a composite index for the common query pattern used by the
--    actions_tab: fetch pending_review + flagged items filtered by account_id.
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_action_items_review_status_account
  ON public.action_items(account_id, review_status)
  WHERE review_status IN ('pending_review', 'flagged');

-- ============================================================================
-- E. Add a check constraint so review_status and needs_review can NEVER
--    contradict each other (defence-in-depth on top of the trigger).
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'action_items_needs_review_consistent'
  ) THEN
    ALTER TABLE public.action_items
      ADD CONSTRAINT action_items_needs_review_consistent
      CHECK (
        -- When review_status is set: needs_review must equal the derived boolean
        (review_status IS NOT NULL AND needs_review = (review_status IN ('pending_review', 'flagged')))
        OR
        -- When review_status is NULL: needs_review must be false (not yet in review workflow)
        (review_status IS NULL AND needs_review = false)
      );
  END IF;
END $$;
