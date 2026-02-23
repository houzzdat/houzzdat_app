-- Migration: Expand notifications CHECK constraints for report sharing
-- Adds 'report_shared' notification type and 'report' reference type.
-- Required for the Push to Owner App feature to create in-app notifications
-- when a manager shares a report with an owner.

-- ============================================================================
-- 1. Expand notifications.type CHECK to include 'report_shared'
-- ============================================================================

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

-- Recreate with the expanded list including 'report_shared'
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
    'critical_detected'::text,
    'report_shared'::text
  ]));

-- ============================================================================
-- 2. Expand notifications.reference_type CHECK to include 'report'
-- ============================================================================

-- Drop ALL check constraints on the reference_type column
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
      AND att.attname = 'reference_type'
      AND con.contype = 'c'
  LOOP
    EXECUTE format('ALTER TABLE public.notifications DROP CONSTRAINT %I', r.conname);
  END LOOP;
END $$;

-- Recreate with the expanded list including 'report'
ALTER TABLE public.notifications ADD CONSTRAINT notifications_reference_type_check
  CHECK (reference_type = ANY (ARRAY[
    'action_item'::text,
    'owner_approval'::text,
    'voice_note'::text,
    'report'::text
  ]));
