-- Finance Module: invoices, payments, owner_payments, fund_requests
-- Migration: 20260210_finance_module.sql

-- ============================================================
-- 1. INVOICES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL,
  account_id uuid NOT NULL,
  invoice_number text NOT NULL,
  vendor text NOT NULL,
  description text,
  amount numeric NOT NULL,
  currency text DEFAULT 'INR',
  due_date date,
  status text DEFAULT 'draft' CHECK (status IN ('draft','submitted','approved','rejected','paid','overdue')),
  attachment_url text,
  submitted_by uuid,
  approved_by uuid,
  approved_at timestamptz,
  paid_at timestamptz,
  rejection_reason text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT invoices_pkey PRIMARY KEY (id),
  CONSTRAINT invoices_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id),
  CONSTRAINT invoices_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id),
  CONSTRAINT invoices_submitted_by_fkey FOREIGN KEY (submitted_by) REFERENCES public.users(id),
  CONSTRAINT invoices_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id)
);

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Account members can view invoices"
  ON public.invoices FOR SELECT
  USING (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can insert invoices"
  ON public.invoices FOR INSERT
  WITH CHECK (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can update invoices"
  ON public.invoices FOR UPDATE
  USING (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

-- ============================================================
-- 2. PAYMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.payments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL,
  account_id uuid NOT NULL,
  invoice_id uuid,
  amount numeric NOT NULL,
  currency text DEFAULT 'INR',
  payment_method text CHECK (payment_method IN ('cash','bank_transfer','upi','cheque','other')),
  reference_number text,
  paid_to text,
  description text,
  paid_by uuid,
  payment_date date DEFAULT CURRENT_DATE,
  attachment_url text,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT payments_pkey PRIMARY KEY (id),
  CONSTRAINT payments_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id),
  CONSTRAINT payments_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id),
  CONSTRAINT payments_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(id),
  CONSTRAINT payments_paid_by_fkey FOREIGN KEY (paid_by) REFERENCES public.users(id)
);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Account members can view payments"
  ON public.payments FOR SELECT
  USING (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can insert payments"
  ON public.payments FOR INSERT
  WITH CHECK (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can update payments"
  ON public.payments FOR UPDATE
  USING (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

-- ============================================================
-- 3. OWNER PAYMENTS (payments received FROM the owner)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.owner_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  project_id uuid,
  account_id uuid NOT NULL,
  owner_id uuid NOT NULL,
  amount numeric NOT NULL,
  currency text DEFAULT 'INR',
  payment_method text CHECK (payment_method IN ('cash','bank_transfer','upi','cheque','other')),
  reference_number text,
  description text,
  received_date date DEFAULT CURRENT_DATE,
  confirmed_by uuid,
  confirmed_at timestamptz,
  allocated_to_project uuid,
  attachment_url text,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT owner_payments_pkey PRIMARY KEY (id),
  CONSTRAINT owner_payments_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id),
  CONSTRAINT owner_payments_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id),
  CONSTRAINT owner_payments_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id),
  CONSTRAINT owner_payments_confirmed_by_fkey FOREIGN KEY (confirmed_by) REFERENCES public.users(id),
  CONSTRAINT owner_payments_allocated_to_project_fkey FOREIGN KEY (allocated_to_project) REFERENCES public.projects(id)
);

ALTER TABLE public.owner_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Account members can view owner_payments"
  ON public.owner_payments FOR SELECT
  USING (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can insert owner_payments"
  ON public.owner_payments FOR INSERT
  WITH CHECK (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can update owner_payments"
  ON public.owner_payments FOR UPDATE
  USING (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

-- ============================================================
-- 4. FUND REQUESTS (requests TO the owner for funds)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.fund_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL,
  account_id uuid NOT NULL,
  owner_id uuid NOT NULL,
  requested_by uuid NOT NULL,
  title text NOT NULL,
  description text,
  amount numeric NOT NULL,
  currency text DEFAULT 'INR',
  urgency text DEFAULT 'normal' CHECK (urgency IN ('low','normal','high','critical')),
  status text DEFAULT 'pending' CHECK (status IN ('pending','approved','denied','partially_approved')),
  approved_amount numeric,
  owner_response text,
  responded_at timestamptz,
  linked_payment_id uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT fund_requests_pkey PRIMARY KEY (id),
  CONSTRAINT fund_requests_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id),
  CONSTRAINT fund_requests_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id),
  CONSTRAINT fund_requests_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id),
  CONSTRAINT fund_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.users(id),
  CONSTRAINT fund_requests_linked_payment_id_fkey FOREIGN KEY (linked_payment_id) REFERENCES public.owner_payments(id)
);

ALTER TABLE public.fund_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Account members can view fund_requests"
  ON public.fund_requests FOR SELECT
  USING (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can insert fund_requests"
  ON public.fund_requests FOR INSERT
  WITH CHECK (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));

CREATE POLICY "Account members can update fund_requests"
  ON public.fund_requests FOR UPDATE
  USING (account_id IN (SELECT account_id FROM public.users WHERE id = auth.uid()));
