-- Migration: Add RLS policies for the accounts table
-- The accounts table has RLS enabled in the live database but no policies
-- allowing super admins or regular users to access it.

-- 1. Super admins can view ALL accounts
CREATE POLICY "Super admins can view all accounts"
  ON public.accounts
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.super_admins
      WHERE super_admins.id = auth.uid()
    )
  );

-- 2. Regular users can view their own company's account
CREATE POLICY "Users can view own account"
  ON public.accounts
  FOR SELECT
  USING (
    id IN (
      SELECT account_id FROM public.users
      WHERE users.id = auth.uid()
    )
  );

-- 3. Super admins can update accounts (for status changes, etc.)
CREATE POLICY "Super admins can update all accounts"
  ON public.accounts
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.super_admins
      WHERE super_admins.id = auth.uid()
    )
  );

-- 4. Super admins can insert accounts (for onboarding)
CREATE POLICY "Super admins can insert accounts"
  ON public.accounts
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.super_admins
      WHERE super_admins.id = auth.uid()
    )
  );
