-- Reset Ranked System
-- Run this in Supabase SQL Editor to migrate to the new points system

-- 1. Reset everyone to 0 points (New Bronze start)
UPDATE public.profiles
SET ranked_points = 0;

-- 2. Update default for NEW users
ALTER TABLE public.profiles 
ALTER COLUMN ranked_points SET DEFAULT 0;

-- 3. Clear existing queue to prevent stale matchmaking
DELETE FROM public.matchmaking_queue;

-- Verified: This sets the baseline for "1 Point = 1 Ranked Point" system starting at 0.
