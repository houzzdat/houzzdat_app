-- Migration: Add preferred_languages array column to users table
-- Supports multi-language user preferences (English + up to 2 Indian languages)

-- 1. Add preferred_languages array column
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS preferred_languages text[] DEFAULT ARRAY['en']::text[];

-- 2. Migrate existing preferred_language values into the new array
-- If a user has a non-null preferred_language, put it as the first element
-- and include 'en' if it's not already the preferred language
UPDATE public.users
SET preferred_languages = CASE
  WHEN preferred_language IS NULL OR preferred_language = 'en' THEN ARRAY['en']::text[]
  ELSE ARRAY[preferred_language, 'en']::text[]
END
WHERE preferred_languages IS NULL OR preferred_languages = ARRAY['en']::text[];

-- 3. Create a trigger to keep preferred_language synced with preferred_languages[1]
-- This ensures backward compatibility: preferred_language always equals the first element
CREATE OR REPLACE FUNCTION sync_preferred_language()
RETURNS TRIGGER AS $$
BEGIN
  -- When preferred_languages is updated, sync preferred_language to the first element
  IF NEW.preferred_languages IS NOT NULL AND array_length(NEW.preferred_languages, 1) > 0 THEN
    NEW.preferred_language := NEW.preferred_languages[1];
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_preferred_language ON public.users;
CREATE TRIGGER trg_sync_preferred_language
  BEFORE INSERT OR UPDATE OF preferred_languages ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION sync_preferred_language();

-- 4. Add a check constraint to limit array size (max 3 languages)
ALTER TABLE public.users
ADD CONSTRAINT chk_preferred_languages_max_3
CHECK (preferred_languages IS NULL OR array_length(preferred_languages, 1) <= 3);
