-- Migration: Agent Orchestration Layer
-- Adds domain routing columns, auto-creation tracking, and new tables for
-- agent processing logs and eval infrastructure.

-- ============================================================================
-- 1. Add domain routing columns to voice_note_ai_analysis
-- ============================================================================

ALTER TABLE public.voice_note_ai_analysis
  ADD COLUMN IF NOT EXISTS domain_tags text[],
  ADD COLUMN IF NOT EXISTS domain_routing jsonb;

COMMENT ON COLUMN public.voice_note_ai_analysis.domain_tags IS 'Agent domains routed to: material, finance, project_state';
COMMENT ON COLUMN public.voice_note_ai_analysis.domain_routing IS 'Per-domain routing metadata: {domain: {reason, confidence, keywords_matched}}';

-- ============================================================================
-- 2. Add auto-creation tracking to material_specs
-- ============================================================================

ALTER TABLE public.material_specs
  ADD COLUMN IF NOT EXISTS needs_confirmation boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS source_voice_note_id uuid REFERENCES public.voice_notes(id),
  ADD COLUMN IF NOT EXISTS auto_created boolean DEFAULT false;

COMMENT ON COLUMN public.material_specs.needs_confirmation IS 'True if material was resolved via LLM (not exact match)';
COMMENT ON COLUMN public.material_specs.source_voice_note_id IS 'Voice note that triggered auto-creation';
COMMENT ON COLUMN public.material_specs.auto_created IS 'True if created by agent orchestration';

-- ============================================================================
-- 3. Add auto-creation tracking to invoices
-- ============================================================================

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS auto_created boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS source_voice_note_id uuid REFERENCES public.voice_notes(id);

-- ============================================================================
-- 4. Add auto-creation tracking to payments
-- ============================================================================

ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS auto_created boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS source_voice_note_id uuid REFERENCES public.voice_notes(id),
  ADD COLUMN IF NOT EXISTS needs_confirmation boolean DEFAULT true;

-- ============================================================================
-- 5. Add auto-creation tracking to fund_requests
-- ============================================================================

ALTER TABLE public.fund_requests
  ADD COLUMN IF NOT EXISTS source_voice_note_id uuid REFERENCES public.voice_notes(id),
  ADD COLUMN IF NOT EXISTS auto_created boolean DEFAULT false;

-- ============================================================================
-- 6. Add auto-creation tracking to owner_payments
-- ============================================================================

ALTER TABLE public.owner_payments
  ADD COLUMN IF NOT EXISTS source_voice_note_id uuid REFERENCES public.voice_notes(id),
  ADD COLUMN IF NOT EXISTS auto_created boolean DEFAULT false;

-- ============================================================================
-- 7. Agent processing log
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.agent_processing_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_note_id uuid NOT NULL REFERENCES public.voice_notes(id) ON DELETE CASCADE,
  agent_name text NOT NULL CHECK (agent_name IN (
    'orchestrator', 'material', 'finance', 'project_state'
  )),
  status text NOT NULL DEFAULT 'running' CHECK (status IN (
    'running', 'success', 'error', 'skipped'
  )),
  input_summary jsonb,
  output_summary jsonb,
  error_message text,
  duration_ms integer,
  idempotency_key text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_agent_log_voice_note ON public.agent_processing_log(voice_note_id);
CREATE INDEX idx_agent_log_status ON public.agent_processing_log(status);
CREATE INDEX idx_agent_log_agent ON public.agent_processing_log(agent_name);
CREATE INDEX idx_agent_log_created ON public.agent_processing_log(created_at DESC);

ALTER TABLE public.agent_processing_log ENABLE ROW LEVEL SECURITY;

-- Service role bypasses RLS; app-level read for dashboard
CREATE POLICY "Service role full access to agent_processing_log"
  ON public.agent_processing_log
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 8. Eval test cases
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.eval_test_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stage text NOT NULL CHECK (stage IN (
    'transcription', 'translation', 'classification', 'agents', 'end_to_end'
  )),
  name text NOT NULL,
  description text,
  -- Input fields (nullable since different stages need different inputs)
  audio_url text,                   -- transcription stage
  source_language text,             -- translation stage
  source_transcript text,           -- translation / classification / agents
  transcript_en text,               -- classification / agents
  project_context jsonb,            -- agents stage (glossary, BOQ, milestones)
  material_requests jsonb,          -- agents stage
  approvals jsonb,                  -- agents stage
  project_events jsonb,             -- agents stage
  -- Expected output
  expected_output jsonb NOT NULL,
  -- Metadata
  tags text[] DEFAULT '{}',
  source text DEFAULT 'manual' CHECK (source IN ('manual', 'seeded', 'imported')),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_eval_cases_stage ON public.eval_test_cases(stage);
CREATE INDEX idx_eval_cases_tags ON public.eval_test_cases USING gin(tags);
CREATE INDEX idx_eval_cases_active ON public.eval_test_cases(is_active) WHERE is_active = true;

ALTER TABLE public.eval_test_cases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access to eval_test_cases"
  ON public.eval_test_cases
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 9. Eval runs
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.eval_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stage text NOT NULL CHECK (stage IN (
    'transcription', 'translation', 'classification', 'agents', 'end_to_end'
  )),
  name text NOT NULL,
  model_name text DEFAULT 'llama-3.3-70b-versatile',
  total_cases integer DEFAULT 0,
  passed integer DEFAULT 0,
  failed integer DEFAULT 0,
  aggregate_scores jsonb DEFAULT '{}'::jsonb,
  status text DEFAULT 'running' CHECK (status IN (
    'running', 'completed', 'failed', 'cancelled'
  )),
  error_message text,
  duration_ms integer,
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);

CREATE INDEX idx_eval_runs_stage ON public.eval_runs(stage);
CREATE INDEX idx_eval_runs_status ON public.eval_runs(status);
CREATE INDEX idx_eval_runs_created ON public.eval_runs(created_at DESC);

ALTER TABLE public.eval_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access to eval_runs"
  ON public.eval_runs
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 10. Eval run results
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.eval_run_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL REFERENCES public.eval_runs(id) ON DELETE CASCADE,
  test_case_id uuid NOT NULL REFERENCES public.eval_test_cases(id) ON DELETE CASCADE,
  actual_output jsonb,
  dimension_scores jsonb DEFAULT '{}'::jsonb,
  passed boolean DEFAULT false,
  diff_summary text,
  error_message text,
  duration_ms integer,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX idx_eval_results_run ON public.eval_run_results(run_id);
CREATE INDEX idx_eval_results_case ON public.eval_run_results(test_case_id);
CREATE INDEX idx_eval_results_passed ON public.eval_run_results(passed);

ALTER TABLE public.eval_run_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role full access to eval_run_results"
  ON public.eval_run_results
  FOR ALL
  USING (true)
  WITH CHECK (true);
