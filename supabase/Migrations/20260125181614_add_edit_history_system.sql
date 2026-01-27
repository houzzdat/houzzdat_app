-- Migration: Add interaction_history to action_items table
-- This enables full audit trail tracking for the Manager Action Lifecycle

-- Add interaction_history column to store JSONB array of interactions
ALTER TABLE public.action_items 
ADD COLUMN IF NOT EXISTS interaction_history JSONB DEFAULT '[]'::jsonb;

-- Create index for better query performance on interaction history
CREATE INDEX IF NOT EXISTS idx_action_items_interaction_history 
ON public.action_items USING gin (interaction_history);

-- Add comment explaining the structure
COMMENT ON COLUMN public.action_items.interaction_history IS 
'Stores audit trail of all manager/stakeholder interactions. Each entry contains: {timestamp, user_id, action, details}';

-- Update existing rows to have empty array if null
UPDATE public.action_items 
SET interaction_history = '[]'::jsonb 
WHERE interaction_history IS NULL;

-- Example interaction_history structure:
/*
[
  {
    "timestamp": "2026-01-25T10:30:00Z",
    "user_id": "uuid-here",
    "action": "approved",
    "details": "Manager approved this action"
  },
  {
    "timestamp": "2026-01-25T11:15:00Z",
    "user_id": "uuid-here", 
    "action": "forwarded",
    "details": "Forwarded to user: uuid-here"
  },
  {
    "timestamp": "2026-01-25T14:45:00Z",
    "user_id": "uuid-here",
    "action": "proof_uploaded",
    "details": "Uploaded proof of work"
  }
]
*/

-- Add trigger to automatically update updated_at when interaction_history changes
CREATE OR REPLACE FUNCTION update_action_items_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_action_items_timestamp
BEFORE UPDATE ON public.action_items
FOR EACH ROW
WHEN (OLD.interaction_history IS DISTINCT FROM NEW.interaction_history)
EXECUTE FUNCTION update_action_items_timestamp();



-- Create bucket for proof photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('proof-photos', 'proof-photos', true);

-- Allow authenticated users to upload
CREATE POLICY "Users can upload proof photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'proof-photos');

-- Allow public read access
CREATE POLICY "Public can view proof photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'proof-photos');