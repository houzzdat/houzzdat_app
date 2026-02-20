-- The voice_notes.category column was declared as USER-DEFINED but no ENUM type
-- existed for it. This broke PostgREST's schema introspection and caused
-- "column status does not exist" errors on ANY update that includes category.
-- Fix: convert to TEXT with CHECK constraint (matches action_items.category pattern).

-- Step 1: Convert the column type to TEXT (idempotent — safe if already text)
DO $$ BEGIN
  ALTER TABLE public.voice_notes
    ALTER COLUMN category TYPE text USING category::text;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'category column already text: %', SQLERRM;
END $$;

-- Step 2: Add CHECK constraint (idempotent — skip if already exists)
DO $$ BEGIN
  ALTER TABLE public.voice_notes
    ADD CONSTRAINT voice_notes_category_check
    CHECK (category IS NULL OR category = ANY (ARRAY[
      'update'::text, 'approval'::text, 'action_required'::text, 'information'::text
    ]));
EXCEPTION WHEN duplicate_object THEN
  RAISE NOTICE 'voice_notes_category_check constraint already exists';
END $$;

-- Step 3: Reload PostgREST schema cache so it picks up the type change
NOTIFY pgrst, 'reload schema';
