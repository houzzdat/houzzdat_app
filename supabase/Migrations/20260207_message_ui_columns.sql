-- ============================================================
-- Migration: Message UI Columns
-- Date: 2026-02-07
-- Purpose: Add confidence routing, review workflow, critical flag
--          columns to action_items, and acknowledgement tracking
--          to voice_notes for ambient updates.
-- ============================================================

-- ----------------------------------------
-- 1. New columns on action_items
-- ----------------------------------------

-- AI confidence score propagated from extraction pipeline
ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  confidence_score numeric DEFAULT NULL;

-- Flag for items requiring manager review before entering standard workflow
ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  needs_review boolean DEFAULT false;

-- Review workflow status
ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  review_status text DEFAULT NULL
  CHECK (review_status IN ('pending_review', 'confirmed', 'dismissed', 'flagged'));

-- Who reviewed and when
ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  reviewed_by uuid REFERENCES users(id) DEFAULT NULL;

ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  reviewed_at timestamptz DEFAULT NULL;

-- Critical/safety flag — triggers Red Alert Banner on manager dashboard
ALTER TABLE action_items ADD COLUMN IF NOT EXISTS
  is_critical_flag boolean DEFAULT false;

-- ----------------------------------------
-- 2. Indexes for new columns
-- ----------------------------------------

CREATE INDEX IF NOT EXISTS idx_action_items_needs_review
  ON action_items(needs_review) WHERE needs_review = true;

CREATE INDEX IF NOT EXISTS idx_action_items_review_status
  ON action_items(review_status) WHERE review_status IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_action_items_is_critical
  ON action_items(is_critical_flag) WHERE is_critical_flag = true;

-- ----------------------------------------
-- 3. Ambient update ACK tracking on voice_notes
-- ----------------------------------------

-- Manager acknowledgement of update-type voice notes in Feed tab
ALTER TABLE voice_notes ADD COLUMN IF NOT EXISTS
  acknowledged_by uuid REFERENCES users(id) DEFAULT NULL;

ALTER TABLE voice_notes ADD COLUMN IF NOT EXISTS
  acknowledged_at timestamptz DEFAULT NULL;
