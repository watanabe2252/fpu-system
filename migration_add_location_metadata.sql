-- Adds antenna-site metadata (elevation, height above ground, antenna gain) to locations.
-- Run this in the Supabase SQL Editor.

alter table public.locations
  add column if not exists elevation double precision,
  add column if not exists height_above_ground double precision,
  add column if not exists antenna_gain double precision;
