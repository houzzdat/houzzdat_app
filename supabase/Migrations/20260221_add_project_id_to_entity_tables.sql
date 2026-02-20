-- Add project_id and account_id to voice note entity tables so they can be
-- queried directly by project without joining through voice_notes.
-- Also backfills existing records from voice_notes.

-- 1. voice_note_material_requests
ALTER TABLE public.voice_note_material_requests
  ADD COLUMN IF NOT EXISTS project_id uuid REFERENCES public.projects(id),
  ADD COLUMN IF NOT EXISTS account_id uuid REFERENCES public.accounts(id);

-- 2. voice_note_labor_requests
ALTER TABLE public.voice_note_labor_requests
  ADD COLUMN IF NOT EXISTS project_id uuid REFERENCES public.projects(id),
  ADD COLUMN IF NOT EXISTS account_id uuid REFERENCES public.accounts(id);

-- 3. voice_note_approvals
ALTER TABLE public.voice_note_approvals
  ADD COLUMN IF NOT EXISTS project_id uuid REFERENCES public.projects(id),
  ADD COLUMN IF NOT EXISTS account_id uuid REFERENCES public.accounts(id);

-- 4. voice_note_project_events
ALTER TABLE public.voice_note_project_events
  ADD COLUMN IF NOT EXISTS project_id uuid REFERENCES public.projects(id),
  ADD COLUMN IF NOT EXISTS account_id uuid REFERENCES public.accounts(id);

-- Backfill existing records from voice_notes
UPDATE public.voice_note_material_requests mr
SET project_id = vn.project_id, account_id = vn.account_id
FROM public.voice_notes vn
WHERE mr.voice_note_id = vn.id AND mr.project_id IS NULL;

UPDATE public.voice_note_labor_requests lr
SET project_id = vn.project_id, account_id = vn.account_id
FROM public.voice_notes vn
WHERE lr.voice_note_id = vn.id AND lr.project_id IS NULL;

UPDATE public.voice_note_approvals a
SET project_id = vn.project_id, account_id = vn.account_id
FROM public.voice_notes vn
WHERE a.voice_note_id = vn.id AND a.project_id IS NULL;

UPDATE public.voice_note_project_events pe
SET project_id = vn.project_id, account_id = vn.account_id
FROM public.voice_notes vn
WHERE pe.voice_note_id = vn.id AND pe.project_id IS NULL;

-- Create indexes for efficient project-scoped queries
CREATE INDEX IF NOT EXISTS idx_material_requests_project ON public.voice_note_material_requests(project_id);
CREATE INDEX IF NOT EXISTS idx_labor_requests_project ON public.voice_note_labor_requests(project_id);
CREATE INDEX IF NOT EXISTS idx_approvals_project ON public.voice_note_approvals(project_id);
CREATE INDEX IF NOT EXISTS idx_project_events_project ON public.voice_note_project_events(project_id);

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
