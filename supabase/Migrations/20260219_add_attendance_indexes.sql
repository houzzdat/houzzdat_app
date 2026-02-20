-- ============================================================================
-- Migration: Add Performance Indexes for Daily Reports
-- Date: 2026-02-19
-- Purpose: Optimize queries for daily report filtering and lookup
-- ============================================================================

-- Index for faster daily report queries
-- Used when excluding daily reports from feed/logs (WHERE report_voice_note_id IS NOT NULL)
CREATE INDEX IF NOT EXISTS idx_attendance_report_voice_note
  ON public.attendance(report_voice_note_id)
  WHERE report_voice_note_id IS NOT NULL;

-- Index for faster worker report lookups
-- Used when workers view their daily reports in attendance tab
CREATE INDEX IF NOT EXISTS idx_attendance_user_checkout
  ON public.attendance(user_id, check_out_at DESC)
  WHERE check_out_at IS NOT NULL;

-- Index for faster manager daily reports by project
-- Used when managers view daily reports tab filtered by project
CREATE INDEX IF NOT EXISTS idx_attendance_project_checkout
  ON public.attendance(project_id, check_out_at DESC)
  WHERE check_out_at IS NOT NULL AND report_voice_note_id IS NOT NULL;

-- Comments for documentation
COMMENT ON INDEX idx_attendance_report_voice_note IS
  'Optimizes queries that filter daily reports by report_voice_note_id';

COMMENT ON INDEX idx_attendance_user_checkout IS
  'Optimizes worker daily reports lookup by user_id and checkout time';

COMMENT ON INDEX idx_attendance_project_checkout IS
  'Optimizes manager daily reports tab queries by project and date range';
