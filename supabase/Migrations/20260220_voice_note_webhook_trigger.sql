-- Migration: Add webhook trigger for completed voice notes
-- Calls the sitevoice-agents webhook when a voice note completes

-- Create webhook trigger function
CREATE OR REPLACE FUNCTION public.trigger_agent_processing()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url text;
  webhook_secret text;
BEGIN
  -- Only trigger for status changes to 'completed'
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN

    -- Get webhook URL and secret from Supabase Vault or set them here
    -- IMPORTANT: Replace with your actual Vercel deployment URL
    webhook_url := 'https://your-deployment.vercel.app/api/webhooks/voice-note-completed';
    webhook_secret := 'a3f8b2c1d4e5f67890abcdef12345678abcdef1234567890abcdef1234567890';

    -- Make async HTTP POST request to webhook using pg_net.
    -- net.http_post() returns a bigint request_id (fire-and-forget).
    PERFORM net.http_post(
      url := webhook_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || webhook_secret
      ),
      body := jsonb_build_object(
        'voice_note_id', NEW.id::text,
        'timestamp', NOW()
      )
    );

    RAISE LOG 'Webhook triggered for voice_note_id: %', NEW.id;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on voice_notes table
DROP TRIGGER IF EXISTS voice_note_completed_webhook ON public.voice_notes;

CREATE TRIGGER voice_note_completed_webhook
  AFTER INSERT OR UPDATE OF status ON public.voice_notes
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_agent_processing();

COMMENT ON FUNCTION public.trigger_agent_processing()
  IS 'Triggers agent processing webhook when voice note status changes to completed';
