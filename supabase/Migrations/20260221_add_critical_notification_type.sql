-- Migration: Expand notifications type CHECK constraint to include 'critical_detected'
-- Required for the transcribe-audio edge function to send safety/critical notifications
-- when critical keywords (injury, fire, collapse, etc.) are detected in voice notes.

-- Drop ALL check constraints on the type column (handles any auto-generated name)
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_attribute att ON att.attnum = ANY(con.conkey)
      AND att.attrelid = con.conrelid
    WHERE con.conrelid = 'public.notifications'::regclass
      AND att.attname = 'type'
      AND con.contype = 'c'
  LOOP
    EXECUTE format('ALTER TABLE public.notifications DROP CONSTRAINT %I', r.conname);
  END LOOP;
END $$;

-- Recreate with the expanded list including 'critical_detected'
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check
  CHECK (type = ANY (ARRAY[
    'action_forwarded'::text,
    'action_instructed'::text,
    'proof_requested'::text,
    'proof_uploaded'::text,
    'status_changed'::text,
    'owner_approval_response'::text,
    'escalated_to_owner'::text,
    'note_added'::text,
    'critical_detected'::text
  ]));
