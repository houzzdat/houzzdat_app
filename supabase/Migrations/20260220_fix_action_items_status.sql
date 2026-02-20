-- Migration: Ensure action_items table has status column
-- This column should exist but may be missing if migrations weren't fully applied

-- Add status column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'action_items'
    AND column_name = 'status'
  ) THEN
    ALTER TABLE public.action_items
      ADD COLUMN status text DEFAULT 'pending'::text
      CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'in_progress'::text, 'verifying'::text, 'completed'::text]));

    RAISE NOTICE 'Added status column to action_items table';
  ELSE
    RAISE NOTICE 'Status column already exists in action_items table';
  END IF;
END $$;
