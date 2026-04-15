-- ============================================================
-- Migration: Expand project stages
-- Run once in the Supabase SQL Editor.
-- ============================================================

-- 1. Drop old CHECK constraint
ALTER TABLE projects DROP CONSTRAINT IF EXISTS projects_status_check;

-- 2. Remap existing values to new stages
UPDATE projects SET status = CASE status
  WHEN 'preparation' THEN 'brainstorming'
  WHEN 'active'      THEN 'data_analysis'
  WHEN 'preprint'    THEN 'submitted'
  WHEN 'submitted'   THEN 'submitted'
  WHEN 'published'   THEN 'accepted'
  ELSE 'brainstorming'
END;

-- 3. New default + CHECK constraint
ALTER TABLE projects ALTER COLUMN status SET DEFAULT 'brainstorming';

ALTER TABLE projects ADD CONSTRAINT projects_status_check
  CHECK (status IN (
    'brainstorming',
    'data_acquisition',
    'data_analysis',
    'writing',
    'coauthor_review',
    'submitted',
    'first_review',
    'accepted',
    'rejected'
  ));
