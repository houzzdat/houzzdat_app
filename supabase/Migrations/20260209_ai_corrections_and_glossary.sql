-- =====================================================
-- AI Corrections & Site Glossary Tables
-- Phase A: Correction feedback loop for AI improvement
-- Phase B: Project-specific glossary for prompt injection
-- =====================================================

-- Phase A: AI Corrections table
-- Captures every manager correction signal to build a self-improving feedback loop.
-- Populated automatically when managers: confirm/dismiss reviews, edit summaries,
-- change priority/category, deny with reason, or promote updates to action items.
CREATE TABLE IF NOT EXISTS ai_corrections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_note_id uuid REFERENCES voice_notes(id) ON DELETE SET NULL,
  action_item_id uuid REFERENCES action_items(id) ON DELETE SET NULL,
  project_id uuid REFERENCES projects(id) ON DELETE SET NULL,
  account_id uuid REFERENCES accounts(id) ON DELETE CASCADE,
  correction_type text NOT NULL CHECK (correction_type IN (
    'category',         -- AI classified wrong category
    'priority',         -- AI assigned wrong priority
    'summary',          -- Manager edited the AI summary
    'review_confirmed', -- Manager confirmed AI suggestion was correct
    'review_dismissed', -- Manager dismissed AI suggestion as wrong
    'promoted_to_action', -- Update was manually promoted to action item
    'denied_with_reason'  -- Denial reason may indicate misclassification
  )),
  original_value text,    -- What the AI originally said
  corrected_value text,   -- What the manager changed it to
  corrected_by uuid REFERENCES auth.users(id),
  confidence_at_time float, -- AI confidence when this correction was made
  created_at timestamptz DEFAULT now()
);

-- Indexes for efficient querying
CREATE INDEX idx_ai_corrections_project ON ai_corrections(project_id);
CREATE INDEX idx_ai_corrections_account ON ai_corrections(account_id);
CREATE INDEX idx_ai_corrections_type ON ai_corrections(correction_type);
CREATE INDEX idx_ai_corrections_created ON ai_corrections(created_at DESC);

-- Phase B: Site Glossary table
-- Project-specific construction terms injected into AI prompts.
-- Managers can add terms specific to their site (material names, brand names,
-- regional shorthand, etc.) to improve transcription and classification accuracy.
CREATE TABLE IF NOT EXISTS site_glossary (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid REFERENCES projects(id) ON DELETE CASCADE,
  account_id uuid REFERENCES accounts(id) ON DELETE CASCADE,
  term text NOT NULL,           -- The term as it might appear in speech
  definition text NOT NULL,     -- What it means (injected into AI prompt)
  category text DEFAULT 'general' CHECK (category IN (
    'material', 'brand', 'tool', 'process', 'location', 'role', 'general'
  )),
  language_hint text,           -- Optional: language the term is typically spoken in
  added_by uuid REFERENCES auth.users(id),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX idx_site_glossary_project ON site_glossary(project_id) WHERE is_active = true;
CREATE INDEX idx_site_glossary_account ON site_glossary(account_id) WHERE is_active = true;

-- Phase D: Materialized view for confidence calibration stats
-- Aggregates weekly confidence metrics for the dashboard widget.
-- Refresh this periodically (e.g., via cron or on-demand).
CREATE MATERIALIZED VIEW IF NOT EXISTS ai_confidence_weekly AS
SELECT
  date_trunc('week', ai.created_at) AS week,
  ai.project_id,
  ai.account_id,
  count(*) AS total_items,
  avg(ai.confidence_score) AS avg_confidence,
  count(*) FILTER (WHERE ai.confidence_score >= 0.85) AS high_confidence_count,
  count(*) FILTER (WHERE ai.confidence_score >= 0.70 AND ai.confidence_score < 0.85) AS medium_confidence_count,
  count(*) FILTER (WHERE ai.confidence_score < 0.70) AS low_confidence_count,
  count(*) FILTER (WHERE ai.needs_review = true) AS review_count,
  count(*) FILTER (WHERE ai.is_critical_flag = true) AS critical_count,
  -- Correction stats
  (SELECT count(*) FROM ai_corrections c
   WHERE c.account_id = ai.account_id
   AND date_trunc('week', c.created_at) = date_trunc('week', ai.created_at)) AS corrections_count,
  (SELECT count(*) FROM ai_corrections c
   WHERE c.account_id = ai.account_id
   AND c.correction_type = 'review_confirmed'
   AND date_trunc('week', c.created_at) = date_trunc('week', ai.created_at)) AS confirmed_count,
  (SELECT count(*) FROM ai_corrections c
   WHERE c.account_id = ai.account_id
   AND c.correction_type = 'review_dismissed'
   AND date_trunc('week', c.created_at) = date_trunc('week', ai.created_at)) AS dismissed_count
FROM action_items ai
WHERE ai.created_at > now() - interval '12 weeks'
GROUP BY 1, 2, 3;

CREATE UNIQUE INDEX idx_ai_confidence_weekly_unique
  ON ai_confidence_weekly(week, project_id, account_id);

-- RLS policies
ALTER TABLE ai_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_glossary ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view corrections in their account"
  ON ai_corrections FOR SELECT
  USING (account_id IN (
    SELECT account_id FROM users WHERE id = auth.uid()
  ));

CREATE POLICY "Managers can insert corrections"
  ON ai_corrections FOR INSERT
  WITH CHECK (corrected_by = auth.uid());

CREATE POLICY "Users can view glossary in their account"
  ON site_glossary FOR SELECT
  USING (account_id IN (
    SELECT account_id FROM users WHERE id = auth.uid()
  ));

CREATE POLICY "Managers can manage glossary"
  ON site_glossary FOR ALL
  USING (account_id IN (
    SELECT account_id FROM users WHERE id = auth.uid()
  ));
