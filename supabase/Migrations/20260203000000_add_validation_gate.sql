-- Migration: Add Validation Gate System
-- Phase 1: Worker Experience Enhancement
-- Purpose: Enable worker confirmation before final submission

-- Add validation status tracking to voice_notes
ALTER TABLE public.voice_notes
  ADD COLUMN IF NOT EXISTS validation_status TEXT DEFAULT 'pending_validation' 
    CHECK (validation_status IN ('pending_validation', 'validated', 'rejected')),
  ADD COLUMN IF NOT EXISTS ai_suggested_summary TEXT,
  ADD COLUMN IF NOT EXISTS ai_suggested_category TEXT,
  ADD COLUMN IF NOT EXISTS worker_confirmed_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS worker_edited_summary TEXT;

-- Add worker-facing directive tracking to action_items
ALTER TABLE public.action_items
  ADD COLUMN IF NOT EXISTS is_directive BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS acknowledged_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS acknowledged_by UUID REFERENCES public.users(id);

-- Create index for worker's personal log queries
CREATE INDEX IF NOT EXISTS idx_voice_notes_user_validated 
  ON public.voice_notes(user_id, validation_status, created_at DESC);

-- Create index for worker's directive queries
CREATE INDEX IF NOT EXISTS idx_action_items_assigned_directive 
  ON public.action_items(assigned_to, is_directive, status);

-- Add comments
COMMENT ON COLUMN public.voice_notes.validation_status IS 'Worker validation state: pending_validation (awaiting confirmation), validated (worker approved), rejected (worker discarded)';
COMMENT ON COLUMN public.voice_notes.ai_suggested_summary IS 'AI-generated summary shown to worker for validation';
COMMENT ON COLUMN public.voice_notes.ai_suggested_category IS 'AI-suggested category shown during validation';
COMMENT ON COLUMN public.voice_notes.worker_confirmed_at IS 'Timestamp when worker confirmed the AI summary';
COMMENT ON COLUMN public.voice_notes.worker_edited_summary IS 'Worker-edited version of the summary (if they chose to modify it)';
COMMENT ON COLUMN public.action_items.is_directive IS 'True if this action was assigned as a directive to a worker';
COMMENT ON COLUMN public.action_items.acknowledged_at IS 'When the worker acknowledged receiving this directive';