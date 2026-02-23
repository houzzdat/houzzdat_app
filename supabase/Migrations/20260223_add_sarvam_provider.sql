-- Migration: Add 'sarvam' as a transcription provider option
-- Sarvam AI provides speech-to-text with native support for 22+ Indian languages

-- Update the CHECK constraint on accounts.transcription_provider to include 'sarvam'
ALTER TABLE public.accounts
  DROP CONSTRAINT IF EXISTS accounts_transcription_provider_check;

ALTER TABLE public.accounts
  ADD CONSTRAINT accounts_transcription_provider_check
  CHECK (transcription_provider = ANY (ARRAY['groq', 'openai', 'gemini', 'sarvam']));

-- Update the CHECK constraint on ai_prompts.provider to include 'sarvam'
ALTER TABLE public.ai_prompts
  DROP CONSTRAINT IF EXISTS ai_prompts_provider_check;

ALTER TABLE public.ai_prompts
  ADD CONSTRAINT ai_prompts_provider_check
  CHECK (provider = ANY (ARRAY['groq', 'openai', 'gemini', 'sarvam']));

-- Add asr_model and translation_model columns to voice_note_ai_analysis
-- so we can tell exactly which model handled each step of the pipeline
ALTER TABLE public.voice_note_ai_analysis
  ADD COLUMN IF NOT EXISTS asr_model TEXT,
  ADD COLUMN IF NOT EXISTS translation_model TEXT;

COMMENT ON COLUMN public.voice_note_ai_analysis.asr_model IS 'Model used for speech-to-text (e.g. whisper-large-v3, saaras:v3, gemini-1.5-flash)';
COMMENT ON COLUMN public.voice_note_ai_analysis.translation_model IS 'Model used for translation to English (e.g. llama-3.3-70b, sarvam-stt-translate, gpt-4o-mini)';

-- Add sarvam_pipeline_mode column to accounts
-- Controls how Sarvam processes voice notes:
--   'two_step' (default): ASR transcription in original language → then translate to English (2 API calls)
--   'single': Direct speech-to-text-translate in one API call (faster, but no original-language transcript)
-- Only used when transcription_provider = 'sarvam'; ignored for other providers.
ALTER TABLE public.accounts
  ADD COLUMN IF NOT EXISTS sarvam_pipeline_mode TEXT DEFAULT 'two_step';

-- Add CHECK constraint separately (handles IF NOT EXISTS on column)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'accounts_sarvam_pipeline_mode_check'
  ) THEN
    ALTER TABLE public.accounts
      ADD CONSTRAINT accounts_sarvam_pipeline_mode_check
      CHECK (sarvam_pipeline_mode IN ('single', 'two_step'));
  END IF;
END $$;

COMMENT ON COLUMN public.accounts.sarvam_pipeline_mode IS 'Sarvam pipeline: single (1 API call, direct translate) or two_step (ASR + translate, preserves original transcript)';

-- Seed translation prompt for Sarvam provider
-- Note: Sarvam handles ASR natively via its own API, but translation/classification
-- still uses an LLM. When provider is 'sarvam', the edge function uses Groq LLM
-- as the fallback for translation and classification since Sarvam is ASR-focused.
INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Construction Translation (Sarvam)',
  'sarvam',
  'translation_normalization',
  'You are a professional translator specializing in construction industry terminology in India.

Translate the following {{LANGUAGE}} construction site voice note into clear, professional English.

RULES:
- Preserve all technical construction terms (e.g., shuttering, centering, TMT bar, RCC, PCC, plaster, aggregate)
- Keep quantities, measurements, and numbers exact
- Maintain the speaker''s intent and urgency level
- If a construction term has no direct English equivalent, keep the original term and add a brief parenthetical explanation
- Do NOT add any information not present in the original
- Return ONLY valid JSON

INPUT TRANSCRIPT:
"{{TRANSCRIPT}}"

Return JSON:
{
  "translated_text": "English translation here",
  "construction_terms_preserved": ["list", "of", "key", "terms"],
  "confidence": 0.0 to 1.0
}',
  1,
  true,
  '{"type": "object", "required": ["translated_text", "confidence"], "properties": {"translated_text": {"type": "string"}, "construction_terms_preserved": {"type": "array", "items": {"type": "string"}}, "confidence": {"type": "number", "minimum": 0, "maximum": 1}}}'::jsonb
)
ON CONFLICT DO NOTHING;

-- Seed voice note analysis prompt for Sarvam provider
INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Voice Note Analysis (Sarvam)',
  'sarvam',
  'voice_note_analysis',
  'You are an AI assistant for a construction project management platform. Analyze the following voice note transcript and extract structured information.

INTENT DEFINITIONS:
- "update": Progress report, status update, informational note (no action needed)
- "approval": Request for permission, authorization, or sign-off to proceed
- "action_required": Problem reported, urgent issue, material/labor request, or task that needs someone to act
- "information": General communication, FYI, or acknowledgment

PRIORITY DEFINITIONS:
- "Low": Routine updates, non-urgent information
- "Med": Standard requests, normal workflow items
- "High": Time-sensitive requests, material shortages, schedule impacts
- "Critical": Safety hazards, structural issues, injuries, emergencies

CLASSIFICATION EXAMPLES:
- "We need 50 bags of cement and 20 TMT bars delivered by tomorrow" -> intent: action_required, priority: High
- "Can we start the second floor slab work?" -> intent: approval, priority: Med
- "First floor plastering is 80% complete" -> intent: update, priority: Low
- "The scaffolding on the east side is shaking, looks unsafe" -> intent: action_required, priority: Critical
- "Received the steel delivery, all counts verified" -> intent: update, priority: Low
- "Need approval for additional 10 workers for next week" -> intent: approval, priority: Med
- "Water is leaking from the third floor ceiling" -> intent: action_required, priority: High

Return ONLY valid JSON with this exact schema:
{
  "intent": "update|approval|action_required|information",
  "priority": "Low|Med|High|Critical",
  "short_summary": "Crisp 1-line summary in active voice starting with a verb (max 15 words)",
  "detailed_summary": "2-3 sentence detailed description",
  "confidence_score": 0.0 to 1.0,
  "materials": [{"name": "...", "quantity": N, "unit": "...", "category": "...", "urgency": "normal|urgent", "confidence": 0.0-1.0}],
  "labor": [{"type": "...", "headcount": N, "duration_days": N, "urgency": "normal|urgent", "confidence": 0.0-1.0}],
  "approvals": [{"type": "...", "amount": N, "currency": "INR", "requires_manager": true, "confidence": 0.0-1.0}],
  "project_events": [{"type": "...", "title": "...", "description": "...", "requires_followup": false, "confidence": 0.0-1.0}]
}',
  1,
  true,
  '{"type": "object", "required": ["intent", "priority", "short_summary", "detailed_summary", "confidence_score"], "properties": {"intent": {"type": "string", "enum": ["update", "approval", "action_required", "information"]}, "priority": {"type": "string", "enum": ["Low", "Med", "High", "Critical"]}, "short_summary": {"type": "string"}, "detailed_summary": {"type": "string"}, "confidence_score": {"type": "number", "minimum": 0, "maximum": 1}, "materials": {"type": "array", "items": {"type": "object", "properties": {"name": {"type": "string"}, "quantity": {"type": "number"}, "unit": {"type": "string"}, "category": {"type": "string"}, "urgency": {"type": "string"}, "confidence": {"type": "number"}}}}, "labor": {"type": "array", "items": {"type": "object", "properties": {"type": {"type": "string"}, "headcount": {"type": "integer"}, "duration_days": {"type": "integer"}, "urgency": {"type": "string"}, "confidence": {"type": "number"}}}}, "approvals": {"type": "array", "items": {"type": "object", "properties": {"type": {"type": "string"}, "amount": {"type": "number"}, "currency": {"type": "string"}, "requires_manager": {"type": "boolean"}, "confidence": {"type": "number"}}}}, "project_events": {"type": "array", "items": {"type": "object", "properties": {"type": {"type": "string"}, "title": {"type": "string"}, "description": {"type": "string"}, "requires_followup": {"type": "boolean"}, "confidence": {"type": "number"}}}}}}'::jsonb
)
ON CONFLICT DO NOTHING;
