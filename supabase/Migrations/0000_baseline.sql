-- Migration: Initial Schema Setup
-- Target: Supabase / PostgreSQL

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create independent tables first
CREATE TABLE public.super_admins (
  id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id),
  email text NOT NULL UNIQUE,
  created_at timestamp with time zone DEFAULT now()
);

-- 2. Create Projects & Accounts (Ordering matters for FKs)
CREATE TABLE public.accounts (
  id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  company_name text NOT NULL,
  admin_id uuid, -- Will link to users later
  created_at timestamp with time zone DEFAULT now(),
  transcription_provider text DEFAULT 'groq' CHECK (transcription_provider = ANY (ARRAY['groq', 'openai', 'gemini']))
);

CREATE TABLE public.projects (
  id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  name text NOT NULL,
  location text,
  account_id uuid NOT NULL REFERENCES public.accounts(id),
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- 3. Create Users (Now includes reports_to for Phase 2 hierarchy)
CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  role text NOT NULL,
  phone_number text,
  current_project_id uuid REFERENCES public.projects(id),
  account_id uuid NOT NULL REFERENCES public.accounts(id),
  email text,
  preferred_language text DEFAULT 'en',
  reports_to uuid REFERENCES public.users(id),
  department text
);

-- 4. Create Voice Notes (Includes Validation Gate columns)
CREATE TABLE public.voice_notes (
  id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id uuid REFERENCES public.users(id),
  project_id uuid NOT NULL REFERENCES public.projects(id),
  account_id uuid NOT NULL REFERENCES public.accounts(id),
  audio_url text NOT NULL,
  transcript_raw text,
  transcript_final text,
  is_edited boolean DEFAULT false,
  processed_json jsonb,
  status text DEFAULT 'processing',
  parent_id uuid REFERENCES public.voice_notes(id),
  recipient_id uuid REFERENCES public.users(id),
  transcription text,
  detected_language text,
  translated_transcription jsonb,
  category text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- 5. Create Action Items (Includes Proof-of-Work & Dependency columns)
CREATE TABLE public.action_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
  voice_note_id uuid REFERENCES public.voice_notes(id),
  project_id uuid NOT NULL REFERENCES public.projects(id),
  account_id uuid NOT NULL REFERENCES public.accounts(id),
  category text NOT NULL CHECK (category = ANY (ARRAY['update', 'approval', 'action_required'])),
  summary text NOT NULL,
  priority text DEFAULT 'Med',
  status text DEFAULT 'pending' CHECK (status = ANY (ARRAY['pending', 'approved', 'rejected', 'in_progress', 'completed'])),
  proof_photo_url text,
  parent_action_id uuid REFERENCES public.action_items(id),
  is_dependency_locked boolean DEFAULT false,
  assigned_to uuid REFERENCES public.users(id),
  user_id uuid REFERENCES public.users(id),
  approved_by uuid REFERENCES public.users(id),
  approved_at timestamp with time zone,
  due_date timestamp with time zone,
  ai_analysis text,
  details text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 6. Supporting tables
CREATE TABLE public.voice_note_forwards (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  original_note_id uuid REFERENCES public.voice_notes(id),
  forwarded_note_id uuid REFERENCES public.voice_notes(id),
  forwarded_from uuid REFERENCES public.users(id),
  forwarded_to uuid REFERENCES public.users(id),
  instruction_note_id uuid REFERENCES public.voice_notes(id),
  created_at timestamp with time zone DEFAULT now()
);