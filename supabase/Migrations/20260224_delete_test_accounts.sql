-- ============================================================================
-- DATA CLEANUP: Delete test/unwanted accounts and all their associated data
-- Date: 2026-02-24
--
-- ACCOUNTS TO DELETE (8):
--   b74ea50b  Able mind
--   68855c5e  Canvasay
--   5f0f176d  I Infrahibiscus (active, 0 projects, 0 users)
--   f01441c9  I Infrahibiscus (active, 0 projects, 0 users)
--   7711092b  I Infrahibiscus (archived, 0 projects, 0 users)
--   acf76e1d  I Infrahibiscus (active, 1 project, 2 users)
--   b42dc968  I Infrahibiscus (active, 0 projects, 0 users)
--   1c8b24bb  Test
--
-- ACCOUNTS PRESERVED (3):
--   570a23bb  houzzdat
--   4d855ca7  ravi avenues
--   f02d3788  RR
--
-- PRESERVED GLOBALLY (never touched):
--   ai_prompts, health_score_weights, super_admins,
--   eval_test_cases, eval_runs, eval_run_results
-- ============================================================================

BEGIN;

-- Convenience: the 8 account IDs to delete
-- Referenced as a subquery throughout so there is no risk of typo in each DELETE.
-- Double-check: houzzdat/ravi avenues/RR are NOT in this list.
DO $$
DECLARE
  keep_names text[] := ARRAY['houzzdat', 'ravi avenues', 'RR'];
  del_count  int;
BEGIN
  -- Safety assertion: none of the 3 keeper accounts are in the target set
  SELECT COUNT(*) INTO del_count
  FROM public.accounts
  WHERE id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db',
    '68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc',
    'f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037',
    'acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25',
    '1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  )
  AND company_name = ANY(keep_names);

  IF del_count > 0 THEN
    RAISE EXCEPTION 'SAFETY ABORT: one of the keeper accounts (houzzdat/ravi avenues/RR) is in the delete list!';
  END IF;

  RAISE NOTICE 'Safety check passed — keeper accounts are NOT in the delete set.';
END $$;


-- ── Shorthand CTE used by every step ─────────────────────────────────────────
-- We derive the set of accounts/projects/users to delete once and reuse it.

-- ── Step 1: Voice note child tables ──────────────────────────────────────────

DELETE FROM public.voice_note_ai_analysis
  WHERE voice_note_id IN (
    SELECT id FROM public.voice_notes
    WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db',
      '68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc',
      'f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037',
      'acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25',
      '1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.voice_note_approvals
  WHERE voice_note_id IN (
    SELECT id FROM public.voice_notes WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.voice_note_edits
  WHERE voice_note_id IN (
    SELECT id FROM public.voice_notes WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.voice_note_labor_requests
  WHERE voice_note_id IN (
    SELECT id FROM public.voice_notes WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.voice_note_material_requests
  WHERE voice_note_id IN (
    SELECT id FROM public.voice_notes WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.voice_note_project_events
  WHERE voice_note_id IN (
    SELECT id FROM public.voice_notes WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.voice_note_forwards
  WHERE original_note_id IN (
    SELECT id FROM public.voice_notes WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  )
  OR forwarded_note_id IN (
    SELECT id FROM public.voice_notes WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.agent_processing_log
  WHERE voice_note_id IN (
    SELECT id FROM public.voice_notes WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

-- ── Step 2: action_items (depend on voice_notes and projects) ─────────────────

-- Child rows of action_items that reference action_items (self-FK)
UPDATE public.action_items
  SET parent_action_id = NULL
  WHERE parent_action_id IN (
    SELECT id FROM public.action_items WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.action_items
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- ── Step 3: voice_notes ───────────────────────────────────────────────────────

DELETE FROM public.voice_notes
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- ── Step 4: Finance / procurement tables scoped to these accounts ─────────────

DELETE FROM public.finance_transactions
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.material_specs
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.owner_approvals
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- payments has a self-FK (possible_duplicate_of) — clear it first
UPDATE public.payments SET possible_duplicate_of = NULL
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.payments
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- invoices has a self-FK (possible_duplicate_of) — clear it first
UPDATE public.invoices SET possible_duplicate_of = NULL
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.invoices
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- fund_requests references owner_payments (linked_payment_id) — delete first
DELETE FROM public.fund_requests
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.owner_payments
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- ── Step 5: Other project-scoped tables ───────────────────────────────────────

DELETE FROM public.design_change_logs
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.notifications
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.reports
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.attendance
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- ── Step 6: Project plan hierarchy (BOQ, budgets, milestones, plans) ──────────

DELETE FROM public.boq_items
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.project_budgets
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.project_milestones
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.project_plans
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- ── Step 7: Projects and project_owners ───────────────────────────────────────

-- Clear current_project_id on users before deleting projects
UPDATE public.users
  SET current_project_id = NULL
  WHERE current_project_id IN (
    SELECT id FROM public.projects WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.project_owners
  WHERE project_id IN (
    SELECT id FROM public.projects WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.projects
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- ── Step 8: Users ─────────────────────────────────────────────────────────────

-- Clear self-FK (reports_to) before deleting users
UPDATE public.users
  SET reports_to = NULL
  WHERE reports_to IN (
    SELECT id FROM public.users WHERE account_id IN (
      'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
      '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
      '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
      'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
    )
  );

DELETE FROM public.user_company_associations
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

DELETE FROM public.users
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- ── Step 9: health_score_weights scoped to these accounts ────────────────────

DELETE FROM public.health_score_weights
  WHERE account_id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- ── Step 10: Finally delete the accounts themselves ───────────────────────────

DELETE FROM public.accounts
  WHERE id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db',
    '68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc',
    'f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037',
    'acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25',
    '1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

-- ── Step 11: Final safety verification ───────────────────────────────────────

DO $$
DECLARE
  remaining_accounts int;
  kept_accounts      int;
BEGIN
  SELECT COUNT(*) INTO remaining_accounts
  FROM public.accounts
  WHERE id IN (
    'b74ea50b-ce6d-4b0e-9537-2a9c2c9376db','68855c5e-ccf5-44ae-b6c7-0ebf1d8dce62',
    '5f0f176d-b8e6-4b14-ac2b-32e41be03dcc','f01441c9-300f-423b-8870-f8e202e37ffd',
    '7711092b-4ddb-47b9-9769-71fe9d0a4037','acf76e1d-185a-4791-97a9-315be29b1b7d',
    'b42dc968-2ba9-4eb5-b92c-21278abe9e25','1c8b24bb-71b8-49f6-b2f7-0443ac15b341'
  );

  SELECT COUNT(*) INTO kept_accounts
  FROM public.accounts
  WHERE id IN (
    '570a23bb-5039-439b-93e4-e23d8ca23bfd',  -- houzzdat
    '4d855ca7-8dcf-4b26-a68c-5a60715d6316',  -- ravi avenues
    'f02d3788-8a34-4d02-87c3-b112dc9dcc08'   -- RR
  );

  IF remaining_accounts > 0 THEN
    RAISE EXCEPTION 'Cleanup incomplete — % target account(s) still exist.', remaining_accounts;
  END IF;

  IF kept_accounts != 3 THEN
    RAISE EXCEPTION 'CRITICAL: Expected 3 keeper accounts (houzzdat/ravi avenues/RR) but found %. ROLLBACK.', kept_accounts;
  END IF;

  RAISE NOTICE 'SUCCESS — 8 accounts deleted, 3 keeper accounts intact (houzzdat, ravi avenues, RR).';
END $$;

COMMIT;
