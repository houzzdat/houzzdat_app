-- ============================================================================
-- RLS POLICIES — Full Database
-- Date: 2026-02-24
--
-- ROLE MODEL:
--   super_admin  — in public.super_admins; can do anything in any account
--   admin        — users.role = 'admin'; full access within their account
--   manager      — users.role = 'manager'; full access within their account
--   owner        — users.role = 'owner'; read-only to their assigned projects
--   worker       — users.role = 'worker'; limited to own voice notes + attendance
--
-- HELPER FUNCTIONS:
--   is_super_admin()          → true if auth.uid() is in super_admins
--   my_account_id()           → account_id of the calling user (from public.users)
--   my_role()                 → role of the calling user
--   is_admin_or_manager()     → true if role is admin or manager
--   is_owner_of_project(pid)  → true if user is mapped in project_owners
--
-- PATTERN:
--   Every account-scoped table uses: account_id = my_account_id()
--   Super admins bypass all restrictions.
--   Service role (edge functions) bypasses RLS automatically.
-- ============================================================================


-- ============================================================================
-- 0. HELPER FUNCTIONS (stable, security-definer so they don't recurse on RLS)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.super_admins WHERE id = auth.uid()
  );
$$;

-- Returns the account_id of the currently logged-in user.
-- Checks both public.users (primary) and user_company_associations (multi-company).
CREATE OR REPLACE FUNCTION public.my_account_id()
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT account_id FROM public.users WHERE id = auth.uid()
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.my_role()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.users WHERE id = auth.uid()
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_admin_or_manager()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT my_role() IN ('admin', 'manager');
$$;

-- True if the calling user is an owner assigned to the given project.
CREATE OR REPLACE FUNCTION public.is_owner_of_project(p_project_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.project_owners
    WHERE project_id = p_project_id AND owner_id = auth.uid()
  );
$$;

-- True if the calling user is in the same account as the given account_id
-- AND has role admin or manager.
CREATE OR REPLACE FUNCTION public.is_account_admin_or_manager(p_account_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND account_id = p_account_id
      AND role IN ('admin', 'manager')
  );
$$;


-- ============================================================================
-- 1. accounts
--    • Super admin: full access
--    • Admin/Manager: can view and update their own account
--    • Owner/Worker: can view their own account (name, settings)
-- ============================================================================

ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "accounts: super admin full access" ON public.accounts;
DROP POLICY IF EXISTS "accounts: members can view own account" ON public.accounts;
DROP POLICY IF EXISTS "accounts: admin can update own account" ON public.accounts;

CREATE POLICY "accounts: super admin full access"
  ON public.accounts FOR ALL
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

CREATE POLICY "accounts: members can view own account"
  ON public.accounts FOR SELECT
  USING (id = my_account_id());

CREATE POLICY "accounts: admin can update own account"
  ON public.accounts FOR UPDATE
  USING (id = my_account_id() AND my_role() = 'admin')
  WITH CHECK (id = my_account_id() AND my_role() = 'admin');


-- ============================================================================
-- 2. users
--    • Super admin: full access
--    • Admin: full access within account
--    • Manager: can view all users in account; can update own profile only
--    • Owner/Worker: can view users in same account; update own profile only
-- ============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users: super admin full access" ON public.users;
DROP POLICY IF EXISTS "users: view same account" ON public.users;
DROP POLICY IF EXISTS "users: admin manage account users" ON public.users;
DROP POLICY IF EXISTS "users: self update profile" ON public.users;

CREATE POLICY "users: super admin full access"
  ON public.users FOR ALL
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

CREATE POLICY "users: view same account"
  ON public.users FOR SELECT
  USING (account_id = my_account_id());

CREATE POLICY "users: admin manage account users"
  ON public.users FOR ALL
  USING (account_id = my_account_id() AND my_role() = 'admin')
  WITH CHECK (account_id = my_account_id() AND my_role() = 'admin');

-- Any user can update their own row (preferred_language, profile fields)
CREATE POLICY "users: self update profile"
  ON public.users FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());


-- ============================================================================
-- 3. projects
--    • Super admin: full access
--    • Admin/Manager: full access within account
--    • Owner: can view projects they are assigned to
--    • Worker: can view projects in their account
-- ============================================================================

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "projects: super admin full access" ON public.projects;
DROP POLICY IF EXISTS "projects: admin manager full access" ON public.projects;
DROP POLICY IF EXISTS "projects: owner view assigned" ON public.projects;
DROP POLICY IF EXISTS "projects: worker view account" ON public.projects;

CREATE POLICY "projects: super admin full access"
  ON public.projects FOR ALL
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

CREATE POLICY "projects: admin manager full access"
  ON public.projects FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());

CREATE POLICY "projects: owner view assigned"
  ON public.projects FOR SELECT
  USING (
    account_id = my_account_id()
    AND my_role() = 'owner'
    AND is_owner_of_project(id)
  );

CREATE POLICY "projects: worker view account"
  ON public.projects FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'worker');


-- ============================================================================
-- 4. project_owners
--    • Super admin: full access
--    • Admin: full CRUD
--    • Manager/Owner/Worker: select only within account
-- ============================================================================

ALTER TABLE public.project_owners ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "project_owners: super admin full access" ON public.project_owners;
DROP POLICY IF EXISTS "project_owners: admin manage" ON public.project_owners;
DROP POLICY IF EXISTS "project_owners: account members view" ON public.project_owners;

CREATE POLICY "project_owners: super admin full access"
  ON public.project_owners FOR ALL
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

CREATE POLICY "project_owners: admin manage"
  ON public.project_owners FOR ALL
  USING (
    my_role() = 'admin'
    AND project_id IN (SELECT id FROM public.projects WHERE account_id = my_account_id())
  )
  WITH CHECK (
    my_role() = 'admin'
    AND project_id IN (SELECT id FROM public.projects WHERE account_id = my_account_id())
  );

CREATE POLICY "project_owners: account members view"
  ON public.project_owners FOR SELECT
  USING (
    project_id IN (SELECT id FROM public.projects WHERE account_id = my_account_id())
  );


-- ============================================================================
-- 5. voice_notes
--    • Super admin: full access
--    • Admin/Manager: full access within account
--    • Owner: view voice notes for their assigned projects
--    • Worker: view and insert own voice notes; update own only
-- ============================================================================

ALTER TABLE public.voice_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "voice_notes: super admin full access" ON public.voice_notes;
DROP POLICY IF EXISTS "voice_notes: admin manager full access" ON public.voice_notes;
DROP POLICY IF EXISTS "voice_notes: owner view assigned projects" ON public.voice_notes;
DROP POLICY IF EXISTS "voice_notes: worker view account" ON public.voice_notes;
DROP POLICY IF EXISTS "voice_notes: worker insert own" ON public.voice_notes;
DROP POLICY IF EXISTS "voice_notes: worker update own" ON public.voice_notes;

CREATE POLICY "voice_notes: super admin full access"
  ON public.voice_notes FOR ALL
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

CREATE POLICY "voice_notes: admin manager full access"
  ON public.voice_notes FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());

CREATE POLICY "voice_notes: owner view assigned projects"
  ON public.voice_notes FOR SELECT
  USING (
    account_id = my_account_id()
    AND my_role() = 'owner'
    AND is_owner_of_project(project_id)
  );

CREATE POLICY "voice_notes: worker view account"
  ON public.voice_notes FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'worker');

CREATE POLICY "voice_notes: worker insert own"
  ON public.voice_notes FOR INSERT
  WITH CHECK (
    account_id = my_account_id()
    AND my_role() = 'worker'
    AND user_id = auth.uid()
  );

CREATE POLICY "voice_notes: worker update own"
  ON public.voice_notes FOR UPDATE
  USING (account_id = my_account_id() AND user_id = auth.uid())
  WITH CHECK (account_id = my_account_id() AND user_id = auth.uid());


-- ============================================================================
-- 6. action_items
--    • Super admin: full access
--    • Admin/Manager: full access within account
--    • Owner: view action items for their assigned projects
--    • Worker: view action items assigned to them or in their project;
--              update status/proof on items assigned to them
-- ============================================================================

ALTER TABLE public.action_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "action_items: super admin full access" ON public.action_items;
DROP POLICY IF EXISTS "action_items: admin manager full access" ON public.action_items;
DROP POLICY IF EXISTS "action_items: owner view assigned projects" ON public.action_items;
DROP POLICY IF EXISTS "action_items: worker view" ON public.action_items;
DROP POLICY IF EXISTS "action_items: worker update assigned" ON public.action_items;

CREATE POLICY "action_items: super admin full access"
  ON public.action_items FOR ALL
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

CREATE POLICY "action_items: admin manager full access"
  ON public.action_items FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());

CREATE POLICY "action_items: owner view assigned projects"
  ON public.action_items FOR SELECT
  USING (
    account_id = my_account_id()
    AND my_role() = 'owner'
    AND is_owner_of_project(project_id)
  );

CREATE POLICY "action_items: worker view"
  ON public.action_items FOR SELECT
  USING (
    account_id = my_account_id()
    AND my_role() = 'worker'
    AND (assigned_to = auth.uid() OR user_id = auth.uid())
  );

CREATE POLICY "action_items: worker update assigned"
  ON public.action_items FOR UPDATE
  USING (
    account_id = my_account_id()
    AND my_role() = 'worker'
    AND assigned_to = auth.uid()
  )
  WITH CHECK (
    account_id = my_account_id()
    AND assigned_to = auth.uid()
  );


-- ============================================================================
-- 7. voice_note_ai_analysis
--    • Super admin: full access
--    • Admin/Manager: full access (reads via voice_note's account)
--    • Owner: view for their projects
--    • Worker: view own voice note analyses
-- ============================================================================

ALTER TABLE public.voice_note_ai_analysis ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vn_ai_analysis: super admin full access" ON public.voice_note_ai_analysis;
DROP POLICY IF EXISTS "vn_ai_analysis: admin manager full access" ON public.voice_note_ai_analysis;
DROP POLICY IF EXISTS "vn_ai_analysis: owner view" ON public.voice_note_ai_analysis;
DROP POLICY IF EXISTS "vn_ai_analysis: worker view own" ON public.voice_note_ai_analysis;

CREATE POLICY "vn_ai_analysis: super admin full access"
  ON public.voice_note_ai_analysis FOR ALL
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

CREATE POLICY "vn_ai_analysis: admin manager full access"
  ON public.voice_note_ai_analysis FOR ALL
  USING (
    voice_note_id IN (
      SELECT id FROM public.voice_notes WHERE account_id = my_account_id()
    )
    AND is_admin_or_manager()
  )
  WITH CHECK (
    voice_note_id IN (
      SELECT id FROM public.voice_notes WHERE account_id = my_account_id()
    )
    AND is_admin_or_manager()
  );

CREATE POLICY "vn_ai_analysis: owner view"
  ON public.voice_note_ai_analysis FOR SELECT
  USING (
    my_role() = 'owner'
    AND voice_note_id IN (
      SELECT id FROM public.voice_notes
      WHERE account_id = my_account_id()
        AND is_owner_of_project(project_id)
    )
  );

CREATE POLICY "vn_ai_analysis: worker view own"
  ON public.voice_note_ai_analysis FOR SELECT
  USING (
    my_role() = 'worker'
    AND voice_note_id IN (
      SELECT id FROM public.voice_notes
      WHERE account_id = my_account_id() AND user_id = auth.uid()
    )
  );


-- ============================================================================
-- 8. voice_note_approvals, voice_note_labor_requests,
--    voice_note_material_requests, voice_note_project_events
--    (same pattern: account-scoped via voice_note → account_id column)
-- ============================================================================

-- voice_note_approvals
ALTER TABLE public.voice_note_approvals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vn_approvals: super admin" ON public.voice_note_approvals;
DROP POLICY IF EXISTS "vn_approvals: admin manager" ON public.voice_note_approvals;
DROP POLICY IF EXISTS "vn_approvals: owner view" ON public.voice_note_approvals;
DROP POLICY IF EXISTS "vn_approvals: worker view own" ON public.voice_note_approvals;

CREATE POLICY "vn_approvals: super admin"
  ON public.voice_note_approvals FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "vn_approvals: admin manager"
  ON public.voice_note_approvals FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "vn_approvals: owner view"
  ON public.voice_note_approvals FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));
CREATE POLICY "vn_approvals: worker view own"
  ON public.voice_note_approvals FOR SELECT
  USING (
    my_role() = 'worker'
    AND voice_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id() AND user_id = auth.uid())
  );

-- voice_note_labor_requests
ALTER TABLE public.voice_note_labor_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vn_labor: super admin" ON public.voice_note_labor_requests;
DROP POLICY IF EXISTS "vn_labor: admin manager" ON public.voice_note_labor_requests;
DROP POLICY IF EXISTS "vn_labor: owner view" ON public.voice_note_labor_requests;
DROP POLICY IF EXISTS "vn_labor: worker view own" ON public.voice_note_labor_requests;

CREATE POLICY "vn_labor: super admin"
  ON public.voice_note_labor_requests FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "vn_labor: admin manager"
  ON public.voice_note_labor_requests FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "vn_labor: owner view"
  ON public.voice_note_labor_requests FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));
CREATE POLICY "vn_labor: worker view own"
  ON public.voice_note_labor_requests FOR SELECT
  USING (
    my_role() = 'worker'
    AND voice_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id() AND user_id = auth.uid())
  );

-- voice_note_material_requests
ALTER TABLE public.voice_note_material_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vn_material_req: super admin" ON public.voice_note_material_requests;
DROP POLICY IF EXISTS "vn_material_req: admin manager" ON public.voice_note_material_requests;
DROP POLICY IF EXISTS "vn_material_req: owner view" ON public.voice_note_material_requests;
DROP POLICY IF EXISTS "vn_material_req: worker view own" ON public.voice_note_material_requests;

CREATE POLICY "vn_material_req: super admin"
  ON public.voice_note_material_requests FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "vn_material_req: admin manager"
  ON public.voice_note_material_requests FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "vn_material_req: owner view"
  ON public.voice_note_material_requests FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));
CREATE POLICY "vn_material_req: worker view own"
  ON public.voice_note_material_requests FOR SELECT
  USING (
    my_role() = 'worker'
    AND voice_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id() AND user_id = auth.uid())
  );

-- voice_note_project_events
ALTER TABLE public.voice_note_project_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vn_project_events: super admin" ON public.voice_note_project_events;
DROP POLICY IF EXISTS "vn_project_events: admin manager" ON public.voice_note_project_events;
DROP POLICY IF EXISTS "vn_project_events: owner view" ON public.voice_note_project_events;
DROP POLICY IF EXISTS "vn_project_events: worker view own" ON public.voice_note_project_events;

CREATE POLICY "vn_project_events: super admin"
  ON public.voice_note_project_events FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "vn_project_events: admin manager"
  ON public.voice_note_project_events FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "vn_project_events: owner view"
  ON public.voice_note_project_events FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));
CREATE POLICY "vn_project_events: worker view own"
  ON public.voice_note_project_events FOR SELECT
  USING (
    my_role() = 'worker'
    AND voice_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id() AND user_id = auth.uid())
  );


-- ============================================================================
-- 9. voice_note_edits
--    • Admin/Manager: full
--    • Worker: view edits on own notes; insert edits on own notes
-- ============================================================================

ALTER TABLE public.voice_note_edits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vn_edits: super admin" ON public.voice_note_edits;
DROP POLICY IF EXISTS "vn_edits: admin manager" ON public.voice_note_edits;
DROP POLICY IF EXISTS "vn_edits: worker view own" ON public.voice_note_edits;
DROP POLICY IF EXISTS "vn_edits: worker insert own" ON public.voice_note_edits;

CREATE POLICY "vn_edits: super admin"
  ON public.voice_note_edits FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "vn_edits: admin manager"
  ON public.voice_note_edits FOR ALL
  USING (
    voice_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id())
    AND is_admin_or_manager()
  )
  WITH CHECK (
    voice_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id())
    AND is_admin_or_manager()
  );
CREATE POLICY "vn_edits: worker view own"
  ON public.voice_note_edits FOR SELECT
  USING (
    voice_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id() AND user_id = auth.uid())
  );
CREATE POLICY "vn_edits: worker insert own"
  ON public.voice_note_edits FOR INSERT
  WITH CHECK (
    voice_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id() AND user_id = auth.uid())
    AND edited_by = auth.uid()
  );


-- ============================================================================
-- 10. voice_note_forwards
--     • Admin/Manager: full within account
--     • Worker: view forwards they sent or received
-- ============================================================================

ALTER TABLE public.voice_note_forwards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vn_forwards: super admin" ON public.voice_note_forwards;
DROP POLICY IF EXISTS "vn_forwards: admin manager" ON public.voice_note_forwards;
DROP POLICY IF EXISTS "vn_forwards: worker view own" ON public.voice_note_forwards;
DROP POLICY IF EXISTS "vn_forwards: worker insert" ON public.voice_note_forwards;

CREATE POLICY "vn_forwards: super admin"
  ON public.voice_note_forwards FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "vn_forwards: admin manager"
  ON public.voice_note_forwards FOR ALL
  USING (
    original_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id())
    AND is_admin_or_manager()
  )
  WITH CHECK (
    original_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id())
    AND is_admin_or_manager()
  );
CREATE POLICY "vn_forwards: worker view own"
  ON public.voice_note_forwards FOR SELECT
  USING (forwarded_from = auth.uid() OR forwarded_to = auth.uid());
CREATE POLICY "vn_forwards: worker insert"
  ON public.voice_note_forwards FOR INSERT
  WITH CHECK (forwarded_from = auth.uid());


-- ============================================================================
-- 11. agent_processing_log
--     • Super admin: full access
--     • Admin/Manager: read only (useful for debugging)
--     • Service role (edge functions): write via service key (bypasses RLS)
-- ============================================================================

ALTER TABLE public.agent_processing_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "agent_log: super admin" ON public.agent_processing_log;
DROP POLICY IF EXISTS "agent_log: admin manager read" ON public.agent_processing_log;

CREATE POLICY "agent_log: super admin"
  ON public.agent_processing_log FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "agent_log: admin manager read"
  ON public.agent_processing_log FOR SELECT
  USING (
    voice_note_id IN (SELECT id FROM public.voice_notes WHERE account_id = my_account_id())
    AND is_admin_or_manager()
  );


-- ============================================================================
-- 12. material_specs
--     • Super admin: full
--     • Admin/Manager: full within account
--     • Owner: view for their projects
--     • Worker: view for their project (no write)
-- ============================================================================

ALTER TABLE public.material_specs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "material_specs: super admin" ON public.material_specs;
DROP POLICY IF EXISTS "material_specs: admin manager" ON public.material_specs;
DROP POLICY IF EXISTS "material_specs: owner view" ON public.material_specs;
DROP POLICY IF EXISTS "material_specs: worker view" ON public.material_specs;

CREATE POLICY "material_specs: super admin"
  ON public.material_specs FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "material_specs: admin manager"
  ON public.material_specs FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "material_specs: owner view"
  ON public.material_specs FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));
CREATE POLICY "material_specs: worker view"
  ON public.material_specs FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'worker');


-- ============================================================================
-- 13. finance_transactions
--     • Super admin: full
--     • Admin/Manager: full within account
--     • Owner: view for their projects
--     • Worker: view transactions they recorded; insert own
-- ============================================================================

ALTER TABLE public.finance_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "finance_tx: super admin" ON public.finance_transactions;
DROP POLICY IF EXISTS "finance_tx: admin manager" ON public.finance_transactions;
DROP POLICY IF EXISTS "finance_tx: owner view" ON public.finance_transactions;
DROP POLICY IF EXISTS "finance_tx: worker view own" ON public.finance_transactions;
DROP POLICY IF EXISTS "finance_tx: worker insert" ON public.finance_transactions;

CREATE POLICY "finance_tx: super admin"
  ON public.finance_transactions FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "finance_tx: admin manager"
  ON public.finance_transactions FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "finance_tx: owner view"
  ON public.finance_transactions FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));
CREATE POLICY "finance_tx: worker view own"
  ON public.finance_transactions FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'worker' AND recorded_by = auth.uid());
CREATE POLICY "finance_tx: worker insert"
  ON public.finance_transactions FOR INSERT
  WITH CHECK (account_id = my_account_id() AND my_role() = 'worker' AND recorded_by = auth.uid());


-- ============================================================================
-- 14. invoices
--     • Super admin: full
--     • Admin/Manager: full within account
--     • Owner: view for their projects
-- ============================================================================

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "invoices: super admin" ON public.invoices;
DROP POLICY IF EXISTS "invoices: admin manager" ON public.invoices;
DROP POLICY IF EXISTS "invoices: owner view" ON public.invoices;

CREATE POLICY "invoices: super admin"
  ON public.invoices FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "invoices: admin manager"
  ON public.invoices FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "invoices: owner view"
  ON public.invoices FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));


-- ============================================================================
-- 15. payments
--     • Super admin: full
--     • Admin/Manager: full within account
--     • Owner: view for their projects
-- ============================================================================

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "payments: super admin" ON public.payments;
DROP POLICY IF EXISTS "payments: admin manager" ON public.payments;
DROP POLICY IF EXISTS "payments: owner view" ON public.payments;

CREATE POLICY "payments: super admin"
  ON public.payments FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "payments: admin manager"
  ON public.payments FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "payments: owner view"
  ON public.payments FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));


-- ============================================================================
-- 16. owner_payments
--     • Super admin: full
--     • Admin/Manager: full within account
--     • Owner: view own payments (where owner_id = auth.uid())
-- ============================================================================

ALTER TABLE public.owner_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "owner_payments: super admin" ON public.owner_payments;
DROP POLICY IF EXISTS "owner_payments: admin manager" ON public.owner_payments;
DROP POLICY IF EXISTS "owner_payments: owner view own" ON public.owner_payments;

CREATE POLICY "owner_payments: super admin"
  ON public.owner_payments FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "owner_payments: admin manager"
  ON public.owner_payments FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "owner_payments: owner view own"
  ON public.owner_payments FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND owner_id = auth.uid());


-- ============================================================================
-- 17. fund_requests
--     • Super admin: full
--     • Admin/Manager: full within account
--     • Owner: view and respond to their own fund requests (owner_id = auth.uid())
-- ============================================================================

ALTER TABLE public.fund_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "fund_requests: super admin" ON public.fund_requests;
DROP POLICY IF EXISTS "fund_requests: admin manager" ON public.fund_requests;
DROP POLICY IF EXISTS "fund_requests: owner view respond" ON public.fund_requests;

CREATE POLICY "fund_requests: super admin"
  ON public.fund_requests FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "fund_requests: admin manager"
  ON public.fund_requests FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "fund_requests: owner view respond"
  ON public.fund_requests FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND owner_id = auth.uid());
-- Owner can update (respond to) fund requests directed at them
CREATE POLICY "fund_requests: owner update respond"
  ON public.fund_requests FOR UPDATE
  USING (account_id = my_account_id() AND my_role() = 'owner' AND owner_id = auth.uid())
  WITH CHECK (account_id = my_account_id() AND owner_id = auth.uid());


-- ============================================================================
-- 18. owner_approvals
--     • Super admin: full
--     • Admin/Manager: full within account
--     • Owner: view and respond to their own approval requests
-- ============================================================================

ALTER TABLE public.owner_approvals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "owner_approvals: super admin" ON public.owner_approvals;
DROP POLICY IF EXISTS "owner_approvals: admin manager" ON public.owner_approvals;
DROP POLICY IF EXISTS "owner_approvals: owner view respond" ON public.owner_approvals;
DROP POLICY IF EXISTS "owner_approvals: owner update respond" ON public.owner_approvals;

CREATE POLICY "owner_approvals: super admin"
  ON public.owner_approvals FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "owner_approvals: admin manager"
  ON public.owner_approvals FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "owner_approvals: owner view respond"
  ON public.owner_approvals FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND owner_id = auth.uid());
CREATE POLICY "owner_approvals: owner update respond"
  ON public.owner_approvals FOR UPDATE
  USING (account_id = my_account_id() AND my_role() = 'owner' AND owner_id = auth.uid())
  WITH CHECK (account_id = my_account_id() AND owner_id = auth.uid());


-- ============================================================================
-- 19. design_change_logs
--     • Super admin: full
--     • Admin/Manager: full within account
--     • Owner: view for their projects
-- ============================================================================

ALTER TABLE public.design_change_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "design_logs: super admin" ON public.design_change_logs;
DROP POLICY IF EXISTS "design_logs: admin manager" ON public.design_change_logs;
DROP POLICY IF EXISTS "design_logs: owner view" ON public.design_change_logs;

CREATE POLICY "design_logs: super admin"
  ON public.design_change_logs FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "design_logs: admin manager"
  ON public.design_change_logs FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "design_logs: owner view"
  ON public.design_change_logs FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));


-- ============================================================================
-- 20. notifications
--     • Super admin: full
--     • Each user sees only their own notifications; can mark read (update)
-- ============================================================================

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "notifications: super admin" ON public.notifications;
DROP POLICY IF EXISTS "notifications: user view own" ON public.notifications;
DROP POLICY IF EXISTS "notifications: user mark read" ON public.notifications;
DROP POLICY IF EXISTS "notifications: admin manager insert" ON public.notifications;

CREATE POLICY "notifications: super admin"
  ON public.notifications FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "notifications: user view own"
  ON public.notifications FOR SELECT
  USING (user_id = auth.uid());
CREATE POLICY "notifications: user mark read"
  ON public.notifications FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
-- Admin/Manager can insert notifications (e.g., send alerts)
CREATE POLICY "notifications: admin manager insert"
  ON public.notifications FOR INSERT
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());


-- ============================================================================
-- 21. attendance
--     • Super admin: full
--     • Admin/Manager: view/update all in account; insert on behalf of workers
--     • Worker: view and insert own attendance
-- ============================================================================

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "attendance: super admin" ON public.attendance;
DROP POLICY IF EXISTS "attendance: admin manager" ON public.attendance;
DROP POLICY IF EXISTS "attendance: worker view own" ON public.attendance;
DROP POLICY IF EXISTS "attendance: worker insert own" ON public.attendance;
DROP POLICY IF EXISTS "attendance: worker update own" ON public.attendance;

CREATE POLICY "attendance: super admin"
  ON public.attendance FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "attendance: admin manager"
  ON public.attendance FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "attendance: worker view own"
  ON public.attendance FOR SELECT
  USING (user_id = auth.uid());
CREATE POLICY "attendance: worker insert own"
  ON public.attendance FOR INSERT
  WITH CHECK (user_id = auth.uid() AND account_id = my_account_id());
CREATE POLICY "attendance: worker update own"
  ON public.attendance FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());


-- ============================================================================
-- 22. reports
--     • Super admin: full
--     • Admin/Manager: full within account
--     • Owner: view reports that include their projects
--       (project_ids is a uuid[]; use && (overlaps) with their assigned projects)
-- ============================================================================

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reports: super admin" ON public.reports;
DROP POLICY IF EXISTS "reports: admin manager" ON public.reports;
DROP POLICY IF EXISTS "reports: owner view" ON public.reports;

CREATE POLICY "reports: super admin"
  ON public.reports FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "reports: admin manager"
  ON public.reports FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "reports: owner view"
  ON public.reports FOR SELECT
  USING (
    account_id = my_account_id()
    AND my_role() = 'owner'
    AND project_ids && ARRAY(
      SELECT po.project_id FROM public.project_owners po WHERE po.owner_id = auth.uid()
    )
  );


-- ============================================================================
-- 23. project_plans, project_milestones, project_budgets, boq_items
--     • Super admin: full
--     • Admin/Manager: full within account
--     • Owner: view for their projects
--     • Worker: view within account (for context)
-- ============================================================================

-- project_plans
ALTER TABLE public.project_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "project_plans: super admin" ON public.project_plans;
DROP POLICY IF EXISTS "project_plans: admin manager" ON public.project_plans;
DROP POLICY IF EXISTS "project_plans: owner view" ON public.project_plans;
DROP POLICY IF EXISTS "project_plans: worker view" ON public.project_plans;

CREATE POLICY "project_plans: super admin"
  ON public.project_plans FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "project_plans: admin manager"
  ON public.project_plans FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "project_plans: owner view"
  ON public.project_plans FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));
CREATE POLICY "project_plans: worker view"
  ON public.project_plans FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'worker');

-- project_milestones
ALTER TABLE public.project_milestones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "milestones: super admin" ON public.project_milestones;
DROP POLICY IF EXISTS "milestones: admin manager" ON public.project_milestones;
DROP POLICY IF EXISTS "milestones: owner view" ON public.project_milestones;
DROP POLICY IF EXISTS "milestones: worker view" ON public.project_milestones;

CREATE POLICY "milestones: super admin"
  ON public.project_milestones FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "milestones: admin manager"
  ON public.project_milestones FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "milestones: owner view"
  ON public.project_milestones FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));
CREATE POLICY "milestones: worker view"
  ON public.project_milestones FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'worker');

-- project_budgets
ALTER TABLE public.project_budgets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "project_budgets: super admin" ON public.project_budgets;
DROP POLICY IF EXISTS "project_budgets: admin manager" ON public.project_budgets;
DROP POLICY IF EXISTS "project_budgets: owner view" ON public.project_budgets;

CREATE POLICY "project_budgets: super admin"
  ON public.project_budgets FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "project_budgets: admin manager"
  ON public.project_budgets FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "project_budgets: owner view"
  ON public.project_budgets FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));

-- boq_items
ALTER TABLE public.boq_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "boq_items: super admin" ON public.boq_items;
DROP POLICY IF EXISTS "boq_items: admin manager" ON public.boq_items;
DROP POLICY IF EXISTS "boq_items: owner view" ON public.boq_items;
DROP POLICY IF EXISTS "boq_items: worker view" ON public.boq_items;

CREATE POLICY "boq_items: super admin"
  ON public.boq_items FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "boq_items: admin manager"
  ON public.boq_items FOR ALL
  USING (account_id = my_account_id() AND is_admin_or_manager())
  WITH CHECK (account_id = my_account_id() AND is_admin_or_manager());
CREATE POLICY "boq_items: owner view"
  ON public.boq_items FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'owner' AND is_owner_of_project(project_id));
CREATE POLICY "boq_items: worker view"
  ON public.boq_items FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'worker');


-- ============================================================================
-- 24. health_score_weights
--     • Super admin: full (manages global row where account_id IS NULL)
--     • Admin: view and update their account's row
--     • Others: read only
-- ============================================================================

ALTER TABLE public.health_score_weights ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "hsw: super admin" ON public.health_score_weights;
DROP POLICY IF EXISTS "hsw: admin manage own" ON public.health_score_weights;
DROP POLICY IF EXISTS "hsw: all read" ON public.health_score_weights;

CREATE POLICY "hsw: super admin"
  ON public.health_score_weights FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "hsw: admin manage own"
  ON public.health_score_weights FOR ALL
  USING (account_id = my_account_id() AND my_role() = 'admin')
  WITH CHECK (account_id = my_account_id() AND my_role() = 'admin');
-- Everyone can read global defaults (account_id IS NULL) and their own account weights
CREATE POLICY "hsw: all read"
  ON public.health_score_weights FOR SELECT
  USING (account_id IS NULL OR account_id = my_account_id());


-- ============================================================================
-- 25. roles
--     • Super admin: full
--     • Admin: manage roles in their account
--     • Others: read roles in their account
-- ============================================================================

ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "roles: super admin" ON public.roles;
DROP POLICY IF EXISTS "roles: admin manage" ON public.roles;
DROP POLICY IF EXISTS "roles: account members read" ON public.roles;

CREATE POLICY "roles: super admin"
  ON public.roles FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "roles: admin manage"
  ON public.roles FOR ALL
  USING (account_id = my_account_id() AND my_role() = 'admin')
  WITH CHECK (account_id = my_account_id() AND my_role() = 'admin');
CREATE POLICY "roles: account members read"
  ON public.roles FOR SELECT
  USING (account_id = my_account_id());


-- ============================================================================
-- 26. user_company_associations
--     • Super admin: full
--     • Admin: manage associations for their account
--     • User: view own associations
-- ============================================================================

ALTER TABLE public.user_company_associations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "uca: super admin" ON public.user_company_associations;
DROP POLICY IF EXISTS "uca: admin manage" ON public.user_company_associations;
DROP POLICY IF EXISTS "uca: user view own" ON public.user_company_associations;

CREATE POLICY "uca: super admin"
  ON public.user_company_associations FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "uca: admin manage"
  ON public.user_company_associations FOR ALL
  USING (account_id = my_account_id() AND my_role() = 'admin')
  WITH CHECK (account_id = my_account_id() AND my_role() = 'admin');
CREATE POLICY "uca: user view own"
  ON public.user_company_associations FOR SELECT
  USING (user_id = auth.uid());


-- ============================================================================
-- 27. user_management_audit_log
--     • Super admin: full
--     • Admin: view audit log for their account
--     • Others: no access
-- ============================================================================

ALTER TABLE public.user_management_audit_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "audit_log: super admin" ON public.user_management_audit_log;
DROP POLICY IF EXISTS "audit_log: admin view" ON public.user_management_audit_log;

CREATE POLICY "audit_log: super admin"
  ON public.user_management_audit_log FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "audit_log: admin view"
  ON public.user_management_audit_log FOR SELECT
  USING (account_id = my_account_id() AND my_role() = 'admin');
-- Only service role / edge functions insert audit log entries (no app-user INSERT policy)


-- ============================================================================
-- 28. super_admins
--     • Super admin: read own row only (prevents privilege escalation)
--     • No other access — management done via Supabase dashboard / service role
-- ============================================================================

ALTER TABLE public.super_admins ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "super_admins: read own" ON public.super_admins;

CREATE POLICY "super_admins: read own"
  ON public.super_admins FOR SELECT
  USING (id = auth.uid());


-- ============================================================================
-- 29. ai_prompts
--     • Super admin: full (add/edit/deactivate prompts)
--     • All authenticated users: read active prompts
--       (app needs to read prompts to display classification results context)
-- ============================================================================

ALTER TABLE public.ai_prompts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ai_prompts: super admin" ON public.ai_prompts;
DROP POLICY IF EXISTS "ai_prompts: all read active" ON public.ai_prompts;

CREATE POLICY "ai_prompts: super admin"
  ON public.ai_prompts FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY "ai_prompts: all read active"
  ON public.ai_prompts FOR SELECT
  USING (is_active = true);


-- ============================================================================
-- 30. eval_test_cases, eval_runs, eval_run_results
--     • Super admin: full
--     • No other access (internal eval infrastructure only)
-- ============================================================================

ALTER TABLE public.eval_test_cases ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "eval_cases: super admin" ON public.eval_test_cases;
CREATE POLICY "eval_cases: super admin"
  ON public.eval_test_cases FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());

ALTER TABLE public.eval_runs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "eval_runs: super admin" ON public.eval_runs;
CREATE POLICY "eval_runs: super admin"
  ON public.eval_runs FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());

ALTER TABLE public.eval_run_results ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "eval_results: super admin" ON public.eval_run_results;
CREATE POLICY "eval_results: super admin"
  ON public.eval_run_results FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
