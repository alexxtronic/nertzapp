-- Reset Ranked System & Fix Schema
-- Run this in Supabase SQL Editor. It handles everything safely.

-- 1. Ensure columns exist on PROFILES
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS ranked_points INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'Bronze',
ADD COLUMN IF NOT EXISTS wins INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS losses INT DEFAULT 0;

-- 2. Ensure columns exist on MATCHMAKING_QUEUE
CREATE TABLE IF NOT EXISTS public.matchmaking_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  avatar_url TEXT,
  ranked_points INT NOT NULL DEFAULT 0,
  status TEXT DEFAULT 'searching',
  match_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  wants_to_start BOOLEAN DEFAULT FALSE,
  UNIQUE(user_id)
);

-- Safely add columns if table already existed but lacked them
ALTER TABLE public.matchmaking_queue 
ADD COLUMN IF NOT EXISTS ranked_points INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now(),
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
ADD COLUMN IF NOT EXISTS avatar_url TEXT,
ADD COLUMN IF NOT EXISTS wants_to_start BOOLEAN DEFAULT FALSE;

-- Safely change match_id to TEXT (casting existing UUIDs if any)
ALTER TABLE public.matchmaking_queue 
ALTER COLUMN match_id TYPE TEXT USING match_id::TEXT;

-- Force Schema Cache Reload (for PostgREST)
NOTIFY pgrst, 'reload schema';

-- ... (Rest of file) ...

-- ============================================
-- FUNCTION: Vote to Start (Atomic)
-- ============================================

CREATE OR REPLACE FUNCTION public.vote_to_start(
  p_user_id UUID
)
RETURNS TEXT AS $$
DECLARE
  v_match_id TEXT;
  v_total_searching INT;
  v_votes INT;
  v_player_ids UUID[];
BEGIN
  -- 1. Mark user as wanting to start
  UPDATE public.matchmaking_queue
  SET wants_to_start = TRUE, updated_at = now()
  WHERE user_id = p_user_id AND status = 'searching';

  RETURN 'VOTED';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Reset everyone to 0 points (New Season Start)
UPDATE public.profiles
SET ranked_points = 0, tier = 'Bronze';

DELETE FROM public.matchmaking_queue;

-- ============================================
-- FUNCTION: Find Ranked Opponents
-- ============================================

CREATE OR REPLACE FUNCTION public.find_ranked_opponents(
  p_user_id UUID,
  p_points INT,
  p_limit INT
)
RETURNS TABLE (
  user_id UUID,
  ranked_points INT,
  score_diff INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    mq.user_id,
    mq.ranked_points,
    ABS(mq.ranked_points - p_points) as score_diff
  FROM public.matchmaking_queue mq
  WHERE mq.status = 'searching'
    AND mq.user_id != p_user_id
    AND mq.updated_at > now() - interval '5 minutes' -- Safety cleanup
  ORDER BY score_diff ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================
-- FUNCTION: Update ELO (Called at game end)
-- ============================================

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


-- ============================================
-- FUNCTION: Create Ranked Match (Atomic)
-- ============================================

-- Drop old versions to prevent ambiguous function call (PGRST203)
DROP FUNCTION IF EXISTS public.create_ranked_match(UUID, UUID[], UUID);
DROP FUNCTION IF EXISTS public.create_ranked_match(UUID, UUID[], TEXT);

CREATE OR REPLACE FUNCTION public.create_ranked_match(
  p_matchmaker_id UUID,
  p_opponent_ids UUID[],
  p_match_id TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_count INT;
BEGIN
  -- 1. Lock rows to prevent race conditions (Atomic Check-and-Set)
  -- If we can't lock all intended players (because they are being matched elsewhere), we allow this to block briefly or check counts.
  -- Better strategy: Lock them if they are 'searching'.
  
  -- Perform a locking SELECT to ensure no one else matches them concurrently
  PERFORM 1 
  FROM public.matchmaking_queue
  WHERE (user_id = p_matchmaker_id OR user_id = ANY(p_opponent_ids))
  AND status = 'searching'
  FOR UPDATE;

  -- 2. Validate counts after acquiring lock
  -- Check p_matchmaker_id
  IF NOT EXISTS (SELECT 1 FROM public.matchmaking_queue WHERE user_id = p_matchmaker_id AND status = 'searching') THEN
    RETURN FALSE;
  END IF;

  -- Check opponents
  SELECT COUNT(*) INTO v_count
  FROM public.matchmaking_queue
  WHERE user_id = ANY(p_opponent_ids) AND status = 'searching';
  
  -- If any opponent was already taken/not found, fail
  IF v_count != array_length(p_opponent_ids, 1) THEN
    RETURN FALSE;
  END IF;

  -- 2. Update status to 'matched' and set match_id
  UPDATE public.matchmaking_queue
  SET 
    status = 'matched',
    match_id = p_match_id,
    updated_at = now()
  WHERE user_id = p_matchmaker_id OR user_id = ANY(p_opponent_ids);
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
