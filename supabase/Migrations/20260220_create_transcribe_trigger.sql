-- Migration: Create trigger to call transcribe-audio edge function on voice note insert
-- This trigger is expected by the mobile app (audio_recorder_service.dart line 179)

-- Ensure pg_net extension is available (required for HTTP calls from triggers)
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Create function that calls the transcribe-audio edge function
CREATE OR REPLACE FUNCTION public.trigger_transcribe_audio()
RETURNS TRIGGER AS $$
DECLARE
  transcribe_url text := 'https://pbnzhevvqjptdfemlqdy.supabase.co/functions/v1/transcribe-audio';
  service_key text;
BEGIN
  -- Only trigger for newly inserted voice notes with status 'processing'
  IF (TG_OP = 'INSERT' AND NEW.status = 'processing') THEN

    -- Try configured service_role_key first (set via ALTER DATABASE postgres
    -- SET app.settings.service_role_key = 'your-key'), then fall back to
    -- the project's public anon key which is sufficient to pass verify_jwt.
    -- The edge function uses its own SUPABASE_SERVICE_ROLE_KEY env for DB ops.
    service_key := coalesce(
      nullif(current_setting('app.settings.service_role_key', true), ''),
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBibnpoZXZ2cWpwdGRmZW1scWR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYxMTU0NzcsImV4cCI6MjA4MTY5MTQ3N30.aUVZwMp8t5ssTm1A6OrF_rV69EEA9NJLkHTM8HW42WI'
    );

    -- Make HTTP POST request to transcribe-audio edge function
    PERFORM net.http_post(
      url := transcribe_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_key
      ),
      body := jsonb_build_object(
        'voice_note_id', NEW.id::text
      )
    );

    RAISE LOG 'Transcribe trigger fired for voice_note_id: %', NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS transcribe_on_insert ON public.voice_notes;

-- Create the trigger on voice_notes table
CREATE TRIGGER transcribe_on_insert
  AFTER INSERT ON public.voice_notes
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_transcribe_audio();

COMMENT ON FUNCTION public.trigger_transcribe_audio()
  IS 'Calls transcribe-audio edge function when a new voice note is inserted. Falls back to anon key if service_role_key not configured.';

COMMENT ON TRIGGER transcribe_on_insert ON public.voice_notes
  IS 'Automatically triggers transcription when a voice note is uploaded';
