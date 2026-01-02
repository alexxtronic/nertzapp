-- Reset Ranked System & Fix Schema
-- Run this in Supabase SQL Editor. It handles everything safely.

-- 1. Ensure columns exist on PROFILES
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS ranked_points INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'Bronze',
ADD COLUMN IF NOT EXISTS wins INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS losses INT DEFAULT 0;

-- 2. Ensure columns exist on MATCHMAKING_QUEUE (Fixing PGRST204 error)
CREATE TABLE IF NOT EXISTS public.matchmaking_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  avatar_url TEXT,
  ranked_points INT NOT NULL DEFAULT 0,
  status TEXT DEFAULT 'searching',
  match_id UUID,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

-- Safely add 'ranked_points' if table already existed but lacked column
ALTER TABLE public.matchmaking_queue 
ADD COLUMN IF NOT EXISTS ranked_points INT DEFAULT 0;

-- Force Schema Cache Reload (for PostgREST)
NOTIFY pgrst, 'reload schema';

-- 3. Update default for NEW users to 0
ALTER TABLE public.profiles 
ALTER COLUMN ranked_points SET DEFAULT 0;

-- 3. Reset everyone to 0 points (New Season Start)
UPDATE public.profiles
SET ranked_points = 0, tier = 'Bronze';

-- 4. Clear existing queue to prevent stale matchmaking
DELETE FROM public.matchmaking_queue;

-- 5. Update the Rank Calculation Logic (Bronze: 0-500, etc)
CREATE OR REPLACE FUNCTION public.update_ranked_result(
  p_user_id UUID,
  p_points_change INT,
  p_is_win BOOLEAN
)
RETURNS void AS $$
DECLARE
  v_new_points INT;
  v_new_tier TEXT;
BEGIN
  -- Update points and stats
  UPDATE public.profiles
  SET 
    ranked_points = GREATEST(0, ranked_points + p_points_change),
    wins = CASE WHEN p_is_win THEN wins + 1 ELSE wins END,
    losses = CASE WHEN NOT p_is_win THEN losses + 1 ELSE losses END
  WHERE id = p_user_id
  RETURNING ranked_points INTO v_new_points;
  
  -- Calculate new tier (Bronze: 0-500, Silver: 500-1000, Gold: 1000-2500, Platinum: 2500-5000, Master: 5000-7500, Legend: 7500+)
  IF v_new_points < 500 THEN v_new_tier := 'Bronze';
  ELSIF v_new_points < 1000 THEN v_new_tier := 'Silver';
  ELSIF v_new_points < 2500 THEN v_new_tier := 'Gold';
  ELSIF v_new_points < 5000 THEN v_new_tier := 'Platinum';
  ELSIF v_new_points < 7500 THEN v_new_tier := 'Master';
  ELSE v_new_tier := 'Legend';
  END IF;
  
  -- Update tier
  UPDATE public.profiles
  SET tier = v_new_tier
  WHERE id = p_user_id;
  
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verified: This fixes schema, resets points, and updates logic all in one go.
