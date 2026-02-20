-- Migration: Hybrid Message-to-Data Capture with Dedup Review Queue
-- Adds quick-tag support, semantic deduplication columns, and completeness tracking
-- for the hybrid AI + optional user-tagging message capture system.

-- ============================================================================
-- 1. Add user_declared_intent to voice_notes
-- ============================================================================
ALTER TABLE public.voice_notes
  ADD COLUMN IF NOT EXISTS user_declared_intent text;

-- Add check constraint separately to handle IF NOT EXISTS pattern
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'voice_notes_user_declared_intent_check'
  ) THEN
    ALTER TABLE public.voice_notes
      ADD CONSTRAINT voice_notes_user_declared_intent_check
      CHECK (user_declared_intent IN (
        'material_received', 'payment_made', 'stage_complete', 'general_update'
      ));
  END IF;
END $$;

COMMENT ON COLUMN public.voice_notes.user_declared_intent
  IS 'Optional quick-tag set by user after recording: material_received, payment_made, stage_complete, general_update';

-- ============================================================================
-- 2. Add quick_tag_enabled per-user toggle
-- ============================================================================
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS quick_tag_enabled boolean DEFAULT NULL;

COMMENT ON COLUMN public.users.quick_tag_enabled
  IS 'Per-user quick-tag toggle. NULL = use account default, true = show, false = hide';

-- ============================================================================
-- 3. Add quick_tag_default per-account toggle
-- ============================================================================
ALTER TABLE public.accounts
  ADD COLUMN IF NOT EXISTS quick_tag_default boolean DEFAULT true;

COMMENT ON COLUMN public.accounts.quick_tag_default
  IS 'Account-level default for quick-tag visibility. Applied when user quick_tag_enabled is NULL';

-- ============================================================================
-- 4. Add dedup + completeness columns to material_specs
-- ============================================================================
ALTER TABLE public.material_specs
  ADD COLUMN IF NOT EXISTS source_event_hash text,
  ADD COLUMN IF NOT EXISTS possible_duplicate_of uuid REFERENCES public.material_specs(id),
  ADD COLUMN IF NOT EXISTS completeness_status text DEFAULT 'complete',
  ADD COLUMN IF NOT EXISTS missing_fields text[] DEFAULT '{}';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'material_specs_completeness_status_check'
  ) THEN
    ALTER TABLE public.material_specs
      ADD CONSTRAINT material_specs_completeness_status_check
      CHECK (completeness_status IN ('complete', 'incomplete'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_material_specs_event_hash
  ON public.material_specs(source_event_hash)
  WHERE source_event_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_material_specs_needs_confirm
  ON public.material_specs(project_id, needs_confirmation)
  WHERE needs_confirmation = true;

CREATE INDEX IF NOT EXISTS idx_material_specs_possible_dup
  ON public.material_specs(possible_duplicate_of)
  WHERE possible_duplicate_of IS NOT NULL;

-- ============================================================================
-- 5. Add dedup + completeness columns to payments
-- ============================================================================
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS source_event_hash text,
  ADD COLUMN IF NOT EXISTS possible_duplicate_of uuid REFERENCES public.payments(id),
  ADD COLUMN IF NOT EXISTS completeness_status text DEFAULT 'complete',
  ADD COLUMN IF NOT EXISTS missing_fields text[] DEFAULT '{}';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'payments_completeness_status_check'
  ) THEN
    ALTER TABLE public.payments
      ADD CONSTRAINT payments_completeness_status_check
      CHECK (completeness_status IN ('complete', 'incomplete'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_payments_event_hash
  ON public.payments(source_event_hash)
  WHERE source_event_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_payments_needs_confirm
  ON public.payments(project_id, needs_confirmation)
  WHERE needs_confirmation = true;

CREATE INDEX IF NOT EXISTS idx_payments_possible_dup
  ON public.payments(possible_duplicate_of)
  WHERE possible_duplicate_of IS NOT NULL;

-- ============================================================================
-- 6. Add dedup columns to invoices
-- ============================================================================
ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS source_event_hash text,
  ADD COLUMN IF NOT EXISTS possible_duplicate_of uuid REFERENCES public.invoices(id);

CREATE INDEX IF NOT EXISTS idx_invoices_event_hash
  ON public.invoices(source_event_hash)
  WHERE source_event_hash IS NOT NULL;

-- ============================================================================
-- 7. Add dedup columns to finance_transactions
-- ============================================================================
ALTER TABLE public.finance_transactions
  ADD COLUMN IF NOT EXISTS possible_duplicate_of uuid REFERENCES public.finance_transactions(id),
  ADD COLUMN IF NOT EXISTS source_event_hash text;

-- ============================================================================
-- 8. Add milestone dedup tracking
-- ============================================================================
ALTER TABLE public.project_milestones
  ADD COLUMN IF NOT EXISTS last_updated_by_voice_note uuid REFERENCES public.voice_notes(id);

COMMENT ON COLUMN public.project_milestones.last_updated_by_voice_note
  IS 'Voice note that last triggered a status update on this milestone. Used for dedup within 24h window.';
