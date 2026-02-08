-- ============================================================================
-- Migration: User & Company Management System
-- Date: 2026-02-08
-- Description: Adds multi-company support, company-scoped roles, soft deletes,
--              company lifecycle management, and audit logging.
-- ============================================================================

-- ============================================================================
-- 1. NEW TABLE: user_company_associations
-- Central table enabling multi-company support with company-scoped roles.
-- One auth user can have multiple associations (one per company).
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.user_company_associations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  account_id uuid NOT NULL,
  role text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  is_primary boolean DEFAULT false,
  joined_at timestamptz DEFAULT now(),
  deactivated_at timestamptz,
  deactivated_by uuid,
  removed_at timestamptz,
  removed_by uuid,

  CONSTRAINT user_company_associations_pkey PRIMARY KEY (id),
  CONSTRAINT user_company_associations_user_account_unique UNIQUE (user_id, account_id),
  CONSTRAINT user_company_associations_status_check CHECK (status IN ('active', 'inactive', 'removed')),
  CONSTRAINT user_company_associations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT user_company_associations_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id),
  CONSTRAINT user_company_associations_deactivated_by_fkey FOREIGN KEY (deactivated_by) REFERENCES auth.users(id),
  CONSTRAINT user_company_associations_removed_by_fkey FOREIGN KEY (removed_by) REFERENCES auth.users(id)
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_uca_user_id ON public.user_company_associations(user_id);
CREATE INDEX IF NOT EXISTS idx_uca_account_id ON public.user_company_associations(account_id);
CREATE INDEX IF NOT EXISTS idx_uca_status ON public.user_company_associations(status);
CREATE INDEX IF NOT EXISTS idx_uca_user_active ON public.user_company_associations(user_id, status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_uca_account_status ON public.user_company_associations(account_id, status);

-- ============================================================================
-- 2. ADD COMPANY STATUS TO accounts TABLE
-- Enables company lifecycle management (active/inactive/archived).
-- ============================================================================
ALTER TABLE public.accounts
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

-- Add check constraint only if not exists (safe approach)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'accounts_status_check'
  ) THEN
    ALTER TABLE public.accounts
      ADD CONSTRAINT accounts_status_check CHECK (status IN ('active', 'inactive', 'archived'));
  END IF;
END $$;

ALTER TABLE public.accounts
  ADD COLUMN IF NOT EXISTS deactivated_at timestamptz,
  ADD COLUMN IF NOT EXISTS archived_at timestamptz;

-- ============================================================================
-- 3. ADD USER STATUS TO users TABLE
-- Enables soft deactivation of users within their active company context.
-- ============================================================================
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'users_status_check'
  ) THEN
    ALTER TABLE public.users
      ADD CONSTRAINT users_status_check CHECK (status IN ('active', 'inactive'));
  END IF;
END $$;

-- ============================================================================
-- 4. AUDIT LOG TABLE
-- Tracks all user and company management actions for accountability.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.user_management_audit_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_id uuid NOT NULL,
  target_user_id uuid,
  account_id uuid NOT NULL,
  action text NOT NULL,
  details jsonb,
  created_at timestamptz DEFAULT now(),

  CONSTRAINT user_management_audit_log_pkey PRIMARY KEY (id),
  CONSTRAINT user_management_audit_log_action_check CHECK (action IN (
    'invite', 'activate', 'deactivate', 'remove',
    'change_role', 'company_activate', 'company_deactivate', 'company_archive',
    'reactivate_association'
  ))
);

CREATE INDEX IF NOT EXISTS idx_audit_target ON public.user_management_audit_log(target_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_account ON public.user_management_audit_log(account_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON public.user_management_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_created ON public.user_management_audit_log(created_at DESC);

-- ============================================================================
-- 5. BACKFILL: Create associations for all existing users
-- Every existing user gets an association row for their current company.
-- ============================================================================
INSERT INTO public.user_company_associations (user_id, account_id, role, status, is_primary, joined_at)
SELECT id, account_id, role, 'active', true, COALESCE(
  (SELECT created_at FROM public.accounts WHERE accounts.id = users.account_id),
  now()
)
FROM public.users
WHERE account_id IS NOT NULL
ON CONFLICT (user_id, account_id) DO NOTHING;

-- ============================================================================
-- 6. DATABASE VIEW: team_members_view
-- Provides a convenient joined view for team member queries.
-- Combines association data with user profile data.
-- ============================================================================
CREATE OR REPLACE VIEW public.team_members_view AS
SELECT
  uca.id AS association_id,
  uca.user_id,
  uca.account_id,
  uca.role,
  uca.status AS association_status,
  uca.is_primary,
  uca.joined_at,
  uca.deactivated_at,
  uca.deactivated_by,
  uca.removed_at,
  uca.removed_by,
  u.email,
  u.full_name,
  u.phone_number,
  u.current_project_id,
  u.preferred_language,
  u.geofence_exempt,
  u.department,
  u.reports_to
FROM public.user_company_associations uca
JOIN public.users u ON u.id = uca.user_id;

-- ============================================================================
-- 7. RLS POLICIES for user_company_associations
-- ============================================================================
ALTER TABLE public.user_company_associations ENABLE ROW LEVEL SECURITY;

-- Users can view associations in their own company
CREATE POLICY "Users can view own company associations"
  ON public.user_company_associations FOR SELECT
  USING (
    account_id IN (
      SELECT account_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Only admins/managers can insert (handled via edge function with service role)
-- Only admins/managers can update (handled via edge function with service role)

-- ============================================================================
-- 8. RLS POLICIES for user_management_audit_log
-- ============================================================================
ALTER TABLE public.user_management_audit_log ENABLE ROW LEVEL SECURITY;

-- Users can view audit logs for their own company
CREATE POLICY "Users can view own company audit logs"
  ON public.user_management_audit_log FOR SELECT
  USING (
    account_id IN (
      SELECT account_id FROM public.users WHERE id = auth.uid()
    )
  );
