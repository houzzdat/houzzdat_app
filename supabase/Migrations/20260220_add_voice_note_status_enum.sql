-- Migration: Add missing voice_note_status ENUM type
-- This ENUM is required by the voice_notes.status column

-- Create the ENUM type if it doesn't exist
DO $$ BEGIN
  CREATE TYPE voice_note_status AS ENUM (
    'processing',
    'transcribed',
    'translated',
    'completed',
    'failed',
    'error'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- If the status column exists but has wrong type, fix it
DO $$
BEGIN
  -- Check if status column exists and fix its type if needed
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'voice_notes'
    AND column_name = 'status'
  ) THEN
    -- Drop trigger temporarily to allow column type change
    DROP TRIGGER IF EXISTS voice_note_completed_webhook ON public.voice_notes;

    -- Alter column to use the ENUM type
    ALTER TABLE public.voice_notes
      ALTER COLUMN status TYPE voice_note_status
      USING status::text::voice_note_status;

    -- Recreate the trigger
    CREATE TRIGGER voice_note_completed_webhook
      AFTER INSERT OR UPDATE OF status ON public.voice_notes
      FOR EACH ROW
      EXECUTE FUNCTION public.trigger_agent_processing();
  ELSE
    -- Add status column if it doesn't exist
    ALTER TABLE public.voice_notes
      ADD COLUMN status voice_note_status DEFAULT 'processing'::voice_note_status;
  END IF;
END $$;

COMMENT ON TYPE voice_note_status IS 'Status values for voice note processing pipeline';
