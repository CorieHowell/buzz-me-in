-- Fix events status check constraint to include 'draft' and 'cancelled'
-- Run this in the Supabase SQL Editor

ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;

ALTER TABLE events ADD CONSTRAINT events_status_check
  CHECK (status IN ('draft', 'confirmed', 'pending_date', 'cancelled'));
