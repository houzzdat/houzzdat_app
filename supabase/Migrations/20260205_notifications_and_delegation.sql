-- Sprint 4: Notifications + Delegation Enhancements
-- Date: 2026-02-05

-- ============================================================
-- 1. Create notifications table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id),
  account_id uuid NOT NULL REFERENCES public.accounts(id),
  project_id uuid REFERENCES public.projects(id),
  type text NOT NULL CHECK (type = ANY(ARRAY[
    'action_forwarded',
    'action_instructed',
    'proof_requested',
    'proof_uploaded',
    'status_changed',
    'owner_approval_response',
    'escalated_to_owner',
    'note_added'
  ])),
  title text NOT NULL,
  body text,
  reference_id uuid,
  reference_type text CHECK (reference_type = ANY(ARRAY[
    'action_item', 'owner_approval', 'voice_note'
  ])),
  is_read boolean DEFAULT false,
  read_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now()
);

-- Indexes for efficient notification queries
CREATE INDEX IF NOT EXISTS idx_notifications_user
  ON public.notifications(user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_account
  ON public.notifications(account_id);

-- ============================================================
-- 2. RLS policies for notifications
-- ============================================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications"
  ON public.notifications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Users can update their own notifications"
  ON public.notifications FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert notifications in their account"
  ON public.notifications FOR INSERT
  WITH CHECK (account_id IN (
    SELECT account_id FROM public.users WHERE id = auth.uid()
  ));

-- ============================================================
-- 3. Add delegation_voice_note_id to action_items
-- ============================================================
-- Links the instruction voice note from manager back to action item
ALTER TABLE public.action_items
  ADD COLUMN IF NOT EXISTS delegation_voice_note_id uuid REFERENCES public.voice_notes(id);

-- ============================================================
-- 4. Add forward_note column to voice_note_forwards
-- ============================================================
-- Optional text note accompanying a forward action
ALTER TABLE public.voice_note_forwards
  ADD COLUMN IF NOT EXISTS forward_note text;
