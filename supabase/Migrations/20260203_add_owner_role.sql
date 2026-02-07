-- Migration: Add Owner Role and Supporting Tables
-- Sprint 1: Owner Screen Foundation

-- 1. Add full_name column to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS full_name text;

-- 2. Create project_owners junction table (owners can have multiple projects)
CREATE TABLE IF NOT EXISTS public.project_owners (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  owner_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  UNIQUE(project_id, owner_id)
);

CREATE INDEX IF NOT EXISTS idx_project_owners_owner ON public.project_owners(owner_id);
CREATE INDEX IF NOT EXISTS idx_project_owners_project ON public.project_owners(project_id);

-- 3. Create owner_approvals table for escalated decisions
CREATE TABLE IF NOT EXISTS public.owner_approvals (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id uuid NOT NULL REFERENCES public.projects(id),
  account_id uuid NOT NULL REFERENCES public.accounts(id),
  requested_by uuid NOT NULL REFERENCES public.users(id),
  owner_id uuid NOT NULL REFERENCES public.users(id),
  title text NOT NULL,
  description text,
  amount numeric,
  currency text DEFAULT 'INR',
  category text NOT NULL CHECK (category = ANY(ARRAY['spending', 'design_change', 'material_change', 'schedule_change', 'other'])),
  status text DEFAULT 'pending' CHECK (status = ANY(ARRAY['pending', 'approved', 'denied', 'deferred'])),
  voice_note_id uuid REFERENCES public.voice_notes(id),
  action_item_id uuid REFERENCES public.action_items(id),
  owner_response text,
  responded_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_owner_approvals_owner ON public.owner_approvals(owner_id);
CREATE INDEX IF NOT EXISTS idx_owner_approvals_status ON public.owner_approvals(status);
CREATE INDEX IF NOT EXISTS idx_owner_approvals_project ON public.owner_approvals(project_id);

-- 4. Create design_change_logs table
CREATE TABLE IF NOT EXISTS public.design_change_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id uuid NOT NULL REFERENCES public.projects(id),
  account_id uuid NOT NULL REFERENCES public.accounts(id),
  title text NOT NULL,
  description text,
  before_spec text,
  after_spec text,
  reason text,
  requested_by uuid NOT NULL REFERENCES public.users(id),
  approved_by uuid REFERENCES public.users(id),
  status text DEFAULT 'proposed' CHECK (status = ANY(ARRAY['proposed', 'approved', 'rejected', 'implemented'])),
  voice_note_id uuid REFERENCES public.voice_notes(id),
  created_at timestamp with time zone DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_design_change_logs_project ON public.design_change_logs(project_id);

-- 5. Create material_specs table
CREATE TABLE IF NOT EXISTS public.material_specs (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id uuid NOT NULL REFERENCES public.projects(id),
  account_id uuid NOT NULL REFERENCES public.accounts(id),
  category text,
  material_name text NOT NULL,
  brand text,
  specification text,
  unit_price numeric,
  unit text,
  quantity numeric,
  vendor text,
  status text DEFAULT 'planned' CHECK (status = ANY(ARRAY['planned', 'ordered', 'delivered', 'installed'])),
  voice_note_id uuid REFERENCES public.voice_notes(id),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_material_specs_project ON public.material_specs(project_id);

-- 6. Add 'verifying' to action_items status CHECK constraint (for Sprint 2)
ALTER TABLE public.action_items DROP CONSTRAINT IF EXISTS action_items_status_check;
ALTER TABLE public.action_items ADD CONSTRAINT action_items_status_check
  CHECK (status = ANY(ARRAY['pending', 'approved', 'rejected', 'in_progress', 'verifying', 'completed']));

-- 7. Add manager_approval column to action_items (if not exists)
ALTER TABLE public.action_items ADD COLUMN IF NOT EXISTS manager_approval boolean DEFAULT false;

-- 8. Auto-update updated_at trigger for owner_approvals
CREATE OR REPLACE FUNCTION update_owner_approvals_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_owner_approvals_timestamp
BEFORE UPDATE ON public.owner_approvals
FOR EACH ROW
EXECUTE FUNCTION update_owner_approvals_timestamp();
