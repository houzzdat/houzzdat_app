-- Migration: Seed default AI prompts for transcription pipeline
-- These prompts are used by the transcribe-audio edge function
-- when no custom prompts exist in the ai_prompts table.

-- ============================================================================
-- TRANSLATION PROMPTS (for Groq provider)
-- ============================================================================

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Construction Translation (Groq)',
  'groq',
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

-- ============================================================================
-- TRANSLATION PROMPTS (for OpenAI provider)
-- ============================================================================

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Construction Translation (OpenAI)',
  'openai',
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

-- ============================================================================
-- TRANSLATION PROMPTS (for Gemini provider)
-- ============================================================================

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Construction Translation (Gemini)',
  'gemini',
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

-- ============================================================================
-- VOICE NOTE ANALYSIS PROMPTS (for Groq provider)
-- ============================================================================

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Voice Note Analysis (Groq)',
  'groq',
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

-- ============================================================================
-- VOICE NOTE ANALYSIS PROMPTS (for OpenAI provider)
-- ============================================================================

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Voice Note Analysis (OpenAI)',
  'openai',
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

-- ============================================================================
-- VOICE NOTE ANALYSIS PROMPTS (for Gemini provider)
-- ============================================================================

INSERT INTO public.ai_prompts (name, provider, purpose, prompt, version, is_active, output_schema)
VALUES (
  'Voice Note Analysis (Gemini)',
  'gemini',
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
