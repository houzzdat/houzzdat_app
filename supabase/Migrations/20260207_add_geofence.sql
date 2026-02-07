-- Geofence support for attendance
-- Date: 2026-02-07

-- 1. Add geofence columns to projects
ALTER TABLE public.projects
  ADD COLUMN IF NOT EXISTS site_latitude double precision,
  ADD COLUMN IF NOT EXISTS site_longitude double precision,
  ADD COLUMN IF NOT EXISTS geofence_radius_m integer NOT NULL DEFAULT 200;

-- 2. Add geofence_exempt flag to users (managers can exempt specific workers)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS geofence_exempt boolean NOT NULL DEFAULT false;

-- 3. Add location columns to attendance for audit trail
ALTER TABLE public.attendance
  ADD COLUMN IF NOT EXISTS check_in_lat double precision,
  ADD COLUMN IF NOT EXISTS check_in_lng double precision,
  ADD COLUMN IF NOT EXISTS check_in_distance_m double precision,
  ADD COLUMN IF NOT EXISTS geofence_overridden boolean NOT NULL DEFAULT false;
