-- ============================================================================
-- DATA CLEANUP: Clear all voice note data and derived records
-- Date: 2026-02-24
--
-- WHAT THIS DELETES:
--   All rows in voice_notes and every table that references it — including
--   AI extractions, action items, agent logs, material specs, payments,
--   invoices, fund requests, finance transactions, design change logs,
--   owner approvals, and attendance voice reports.
--
-- WHAT THIS PRESERVES (untouched):
--   accounts, users, projects, project_owners, roles
--   ai_prompts, health_score_weights
--   project_plans, project_milestones, project_budgets, boq_items
--   notifications, reports
--   eval_test_cases, eval_runs, eval_run_results
--   super_admins, user_company_associations, user_management_audit_log
--   ai_corrections, glossary (if present)
--
-- HOW TO RUN:
--   Paste into the Supabase SQL Editor and execute.
--   It is wrapped in a transaction so if anything fails, nothing is deleted.
-- ============================================================================

BEGIN;

-- ── Step 1: Child tables that directly reference voice_notes ─────────────────
-- These are cleared first to satisfy FK constraints before we touch voice_notes.

-- AI extraction sub-tables (no FKs on anything else)
DELETE FROM public.voice_note_ai_analysis;
DELETE FROM public.voice_note_approvals;
DELETE FROM public.voice_note_edits;
DELETE FROM public.voice_note_labor_requests;
DELETE FROM public.voice_note_material_requests;
DELETE FROM public.voice_note_project_events;

-- Agent processing log (FK → voice_notes, CASCADE in original migration but
-- live schema shows plain FK — delete explicitly to be safe)
DELETE FROM public.agent_processing_log;

-- ── Step 2: Clear the voice_note_id / source_voice_note_id pointer on tables
--    that we KEEP but whose FK column must be nulled before deleting voice_notes.
-- ── These tables contain business data we are NOT deleting ──────────────────

-- action_items created from voice notes — NULL the FK pointers, then delete
-- the action items themselves (they were AI-generated from voice notes and
-- are meaningless without the source).
-- If you want to KEEP manually-created action items, change DELETE → UPDATE below.
DELETE FROM public.action_items;

-- design_change_logs referenced voice notes — NULL the FK, keep the log row
UPDATE public.design_change_logs SET voice_note_id = NULL WHERE voice_note_id IS NOT NULL;

-- finance_transactions: NULL the voice_note_id FK pointer
UPDATE public.finance_transactions SET voice_note_id = NULL WHERE voice_note_id IS NOT NULL;

-- material_specs: clear both voice_note_id and source_voice_note_id pointers
UPDATE public.material_specs
  SET voice_note_id        = NULL,
      source_voice_note_id = NULL,
      auto_created         = false,
      source_event_hash    = NULL,
      possible_duplicate_of = NULL
  WHERE voice_note_id IS NOT NULL OR source_voice_note_id IS NOT NULL;

-- owner_approvals: NULL the voice_note_id FK pointer
UPDATE public.owner_approvals SET voice_note_id = NULL WHERE voice_note_id IS NOT NULL;

-- payments: clear source_voice_note_id pointer (auto-created payments from voice notes)
UPDATE public.payments
  SET source_voice_note_id  = NULL,
      auto_created           = false,
      source_event_hash      = NULL,
      possible_duplicate_of  = NULL
  WHERE source_voice_note_id IS NOT NULL;

-- invoices: clear source_voice_note_id pointer
UPDATE public.invoices
  SET source_voice_note_id  = NULL,
      auto_created           = false,
      source_event_hash      = NULL,
      possible_duplicate_of  = NULL
  WHERE source_voice_note_id IS NOT NULL;

-- fund_requests: clear source_voice_note_id pointer
UPDATE public.fund_requests
  SET source_voice_note_id = NULL,
      auto_created         = false
  WHERE source_voice_note_id IS NOT NULL;

-- owner_payments: clear source_voice_note_id pointer
UPDATE public.owner_payments
  SET source_voice_note_id = NULL,
      auto_created         = false
  WHERE source_voice_note_id IS NOT NULL;

-- attendance: NULL the report_voice_note_id pointer (keep attendance records)
UPDATE public.attendance
  SET report_voice_note_id = NULL,
      report_type          = NULL,
      report_text          = NULL
  WHERE report_voice_note_id IS NOT NULL;

-- project_milestones: NULL the last_updated_by_voice_note pointer
UPDATE public.project_milestones
  SET last_updated_by_voice_note = NULL
  WHERE last_updated_by_voice_note IS NOT NULL;

-- ── Step 3: voice_note_forwards — self-referencing table, clear it entirely ──
DELETE FROM public.voice_note_forwards;

-- ── Step 4: voice_notes — now safe to delete (all FK children are cleared) ───
DELETE FROM public.voice_notes;

-- ── Step 5: Verify counts (these should all be 0) ────────────────────────────
DO $$
DECLARE
  vn_count   int;
  ai_count   int;
  ai_log     int;
  fwd_count  int;
BEGIN
  SELECT COUNT(*) INTO vn_count  FROM public.voice_notes;
  SELECT COUNT(*) INTO ai_count  FROM public.voice_note_ai_analysis;
  SELECT COUNT(*) INTO ai_log    FROM public.agent_processing_log;
  SELECT COUNT(*) INTO fwd_count FROM public.voice_note_forwards;

  IF vn_count > 0 OR ai_count > 0 OR ai_log > 0 OR fwd_count > 0 THEN
    RAISE EXCEPTION
      'Cleanup incomplete — remaining rows: voice_notes=%, voice_note_ai_analysis=%, agent_processing_log=%, voice_note_forwards=%',
      vn_count, ai_count, ai_log, fwd_count;
  ELSE
    RAISE NOTICE 'Voice note data cleared successfully. All verification counts = 0.';
  END IF;
END $$;

COMMIT;
