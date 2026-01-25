-- Migration: Add Edit History System of Record Columns
-- Created: 2025-01-24
-- Purpose: Implement immutable transcription tracking with edit history

-- Add new columns for System of Record
ALTER TABLE public.voice_notes
  ADD COLUMN IF NOT EXISTS transcript_raw TEXT,
  ADD COLUMN IF NOT EXISTS detected_language_code TEXT,
  ADD COLUMN IF NOT EXISTS edit_history JSONB DEFAULT '[]'::jsonb;

-- Migrate existing data
-- Copy existing transcription to transcript_raw (one-time backfill)
UPDATE public.voice_notes
SET transcript_raw = transcription
WHERE transcript_raw IS NULL
  AND transcription IS NOT NULL;

-- Copy existing detected_language to detected_language_code
UPDATE public.voice_notes
SET detected_language_code = detected_language
WHERE detected_language_code IS NULL
  AND detected_language IS NOT NULL;

-- Add comments for clarity
COMMENT ON COLUMN public.voice_notes.transcript_raw IS 'IMMUTABLE: Original AI transcription - NEVER overwrite after initial AI processing';
COMMENT ON COLUMN public.voice_notes.detected_language_code IS 'ISO 639-1 language code (e.g., en, te, hi, ta)';
COMMENT ON COLUMN public.voice_notes.edit_history IS 'JSONB array of edit records with version history';
COMMENT ON COLUMN public.voice_notes.transcription IS 'Display version: Shows latest edit or original if not edited (for backward compatibility)';
COMMENT ON COLUMN public.voice_notes.is_edited IS 'Quick flag: true after first edit, prevents subsequent edits';

-- Create index for faster queries on edited status
CREATE INDEX IF NOT EXISTS idx_voice_notes_is_edited ON public.voice_notes(is_edited);

-- Create index for language code queries
CREATE INDEX IF NOT EXISTS idx_voice_notes_language ON public.voice_notes(detected_language_code);

-- Optional: Create GIN index for edit_history JSONB queries (if you'll query history frequently)
CREATE INDEX IF NOT EXISTS idx_voice_notes_edit_history ON public.voice_notes USING GIN (edit_history);