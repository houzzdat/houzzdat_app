--Add new canonical transcript fields

ALTER TABLE voice_notes
ADD COLUMN transcript_raw_original TEXT,
ADD COLUMN transcript_en_original TEXT,
ADD COLUMN transcript_raw_current TEXT,
ADD COLUMN transcript_en_current TEXT,
ADD COLUMN asr_confidence NUMERIC,
ADD COLUMN transcription_locked BOOLEAN DEFAULT false,
ADD COLUMN last_edited_by UUID REFERENCES users(id),
ADD COLUMN last_edited_at TIMESTAMP;


--Normalize language fields
-- If both exist, enforce meaning
ALTER TABLE voice_notes
ALTER COLUMN detected_language_code TYPE TEXT,
ALTER COLUMN detected_language TYPE TEXT;

--Deprecate redundant fields (DO NOT drop yet)
COMMENT ON COLUMN voice_notes.transcript_raw IS 'DEPRECATED: use transcript_raw_original/current';
COMMENT ON COLUMN voice_notes.transcription IS 'DEPRECATED: use transcript_en_original/current';
COMMENT ON COLUMN voice_notes.transcript_final IS 'DEPRECATED';
COMMENT ON COLUMN voice_notes.translated_transcription IS 'DEPRECATED';
COMMENT ON COLUMN voice_notes.processed_json IS 'DEPRECATED';
COMMENT ON COLUMN voice_notes.category IS 'DEPRECATED';

--Create edit log table
CREATE TABLE voice_note_edits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_note_id UUID REFERENCES voice_notes(id) ON DELETE CASCADE,
  edit_number INTEGER NOT NULL,
  before_text TEXT NOT NULL,
  after_text TEXT NOT NULL,
  edited_by UUID REFERENCES users(id),
  edit_reason TEXT CHECK (
    edit_reason IN ('typo', 'translation_fix', 'clarification', 'other')
  ),
  edited_at TIMESTAMP DEFAULT now()
);

--Enforce immutability of originals
CREATE OR REPLACE FUNCTION prevent_original_transcript_update()
RETURNS trigger AS $$
BEGIN
  IF NEW.transcript_raw_original IS DISTINCT FROM OLD.transcript_raw_original
     OR NEW.transcript_en_original IS DISTINCT FROM OLD.transcript_en_original THEN
    RAISE EXCEPTION 'Original transcripts cannot be modified';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lock_original_transcripts
BEFORE UPDATE ON voice_notes
FOR EACH ROW
EXECUTE FUNCTION prevent_original_transcript_update();

--Table: voice_note_ai_analysis. This is the primary AI output record

CREATE TABLE voice_note_ai_analysis (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_note_id UUID REFERENCES voice_notes(id) ON DELETE CASCADE,

  source_transcript TEXT CHECK (source_transcript IN ('original', 'edited')),
  edit_version INTEGER,

  intent TEXT CHECK (
    intent IN ('update', 'approval', 'action_required', 'information')
  ),

  priority TEXT CHECK (
    priority IN ('Low', 'Med', 'High', 'Critical')
  ),

  short_summary TEXT NOT NULL,
  detailed_summary TEXT,

  confidence_score NUMERIC,
  ai_model TEXT,
  prompt_version TEXT,

  created_at TIMESTAMP DEFAULT now()
);

--Table: voice_note_material_requests.This feeds directly into procurement.

CREATE TABLE voice_note_material_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_note_id UUID REFERENCES voice_notes(id) ON DELETE CASCADE,

  material_category TEXT,
  material_name TEXT,
  quantity NUMERIC,
  unit TEXT,
  brand_preference TEXT,
  delivery_date DATE,
  urgency TEXT CHECK (urgency IN ('normal', 'urgent')),

  extracted_from TEXT CHECK (extracted_from IN ('explicit', 'implicit')),
  confidence_score NUMERIC,

  created_at TIMESTAMP DEFAULT now()
);

--Table: voice_note_labor_requests
CREATE TABLE voice_note_labor_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_note_id UUID REFERENCES voice_notes(id) ON DELETE CASCADE,

  labor_type TEXT,
  headcount INTEGER,
  duration_days INTEGER,
  start_date DATE,
  urgency TEXT CHECK (urgency IN ('normal', 'urgent')),

  confidence_score NUMERIC,

  created_at TIMESTAMP DEFAULT now()
);


--Table: voice_note_approvals
CREATE TABLE voice_note_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_note_id UUID REFERENCES voice_notes(id) ON DELETE CASCADE,

  approval_type TEXT,
  amount NUMERIC,
  currency TEXT DEFAULT 'INR',
  due_date DATE,

  requires_manager BOOLEAN,
  confidence_score NUMERIC,

  created_at TIMESTAMP DEFAULT now()
);


--voice_note_project_events This captures everything that is NOT procurement / labour / finance.
CREATE TABLE voice_note_project_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  voice_note_id UUID REFERENCES voice_notes(id) ON DELETE CASCADE,

  event_type TEXT CHECK (
    event_type IN (
      'project_update',
      'issue_reported',
      'approval_request',
      'instruction',
      'information'
    )
  ),

  title TEXT NOT NULL,
  description TEXT,

  requires_followup BOOLEAN DEFAULT false,
  suggested_due_date DATE,
  suggested_assignee UUID REFERENCES users(id),

  confidence_score NUMERIC,

  created_at TIMESTAMP DEFAULT now()
);

--Prompt Registry Table
CREATE TABLE ai_prompts (
id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
name TEXT NOT NULL,
provider TEXT CHECK (provider IN ('groq', 'openai', 'gemini')) NOT NULL,
purpose TEXT NOT NULL, -- e.g. voice_note_understanding
version INTEGER NOT NULL,
prompt TEXT NOT NULL,
output_schema JSONB NOT NULL,
is_active BOOLEAN DEFAULT true,
created_at TIMESTAMP DEFAULT now(),
UNIQUE (provider, purpose, version)
);


