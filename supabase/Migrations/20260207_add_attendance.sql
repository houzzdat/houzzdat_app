-- Attendance tracking for workers
-- Date: 2026-02-07

CREATE TABLE IF NOT EXISTS public.attendance (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.users(id),
  account_id uuid NOT NULL REFERENCES public.accounts(id),
  project_id uuid REFERENCES public.projects(id),
  check_in_at timestamp with time zone NOT NULL DEFAULT now(),
  check_out_at timestamp with time zone,
  report_type text CHECK (report_type = ANY(ARRAY['voice'::text, 'text'::text])),
  report_text text,
  report_voice_note_id uuid REFERENCES public.voice_notes(id),
  created_at timestamp with time zone DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_attendance_user
  ON public.attendance(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_attendance_account
  ON public.attendance(account_id);

-- RLS
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view attendance in their account"
  ON public.attendance FOR SELECT
  USING (account_id IN (
    SELECT account_id FROM public.users WHERE id = auth.uid()
  ));

CREATE POLICY "Users can insert their own attendance"
  ON public.attendance FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own attendance"
  ON public.attendance FOR UPDATE
  USING (user_id = auth.uid());
