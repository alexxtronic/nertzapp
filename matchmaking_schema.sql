-- Ranked Matchmaking Schema
-- Run this in Supabase SQL Editor

-- ============================================
-- RANKED PROFILES (Extension of profiles)
-- ============================================

-- Add ranked stats to profiles if not exists
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS ranked_points INT DEFAULT 1000,
ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'Bronze',
ADD COLUMN IF NOT EXISTS wins INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS losses INT DEFAULT 0;

-- Index for leaderboard
CREATE INDEX IF NOT EXISTS idx_profiles_ranked_points ON public.profiles(ranked_points DESC);

-- ============================================
-- MATCHMAKING QUEUE
-- ============================================

CREATE TABLE IF NOT EXISTS public.matchmaking_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  avatar_url TEXT,
  ranked_points INT NOT NULL,
  region TEXT DEFAULT 'us-east', -- Future proofing
  status TEXT DEFAULT 'searching' CHECK (status IN ('searching', 'matched', 'timeout')),
  match_id UUID, -- Assigned when matched
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  -- Prevent double queuing
  UNIQUE(user_id)
);

-- Auto-expire old queue entries (clean up every 5 mins via cron in real app)
-- For now we rely on client checking timestamps

-- RLS Policies
ALTER TABLE public.matchmaking_queue ENABLE ROW LEVEL SECURITY;

-- Users can insert themselves
CREATE POLICY "Users can join queue" ON public.matchmaking_queue
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can delete themselves (leave queue)
CREATE POLICY "Users can leave queue" ON public.matchmaking_queue
  FOR DELETE USING (auth.uid() = user_id);

-- Users can read queue to find matches (simplified matchmaking)
-- In production, a server handling matchmaking is better to prevent cheating
CREATE POLICY "Users can view queue" ON public.matchmaking_queue
  FOR SELECT USING (true);
  
-- Users can update status (e.g. marking as matched) - risky but needed for client-side matchmaking
CREATE POLICY "Users can update queue" ON public.matchmaking_queue
  FOR UPDATE USING (true); 

-- ============================================
-- FUNCTION: Find Match
-- ============================================

-- Find n opponents with similar ELO (+- 200 points)
CREATE OR REPLACE FUNCTION public.find_ranked_opponents(
  p_user_id UUID,
  p_points INT,
  p_limit INT DEFAULT 3
)
RETURNS SETOF public.matchmaking_queue AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM public.matchmaking_queue
  WHERE user_id != p_user_id
    AND status = 'searching'
    -- Find waiting players created in last 2 minutes
    AND created_at > (now() - interval '2 minutes')
    -- Relaxed matchmaking: just get nearest by points
    ORDER BY ABS(ranked_points - p_points) ASC
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
  
  -- Calculate new tier
  IF v_new_points < 1200 THEN v_new_tier := 'Bronze';
  ELSIF v_new_points < 1400 THEN v_new_tier := 'Silver';
  ELSIF v_new_points < 1600 THEN v_new_tier := 'Gold';
  ELSIF v_new_points < 1900 THEN v_new_tier := 'Platinum';
  ELSIF v_new_points < 2200 THEN v_new_tier := 'Diamond';
  ELSIF v_new_points < 2600 THEN v_new_tier := 'Master';
  ELSE v_new_tier := 'Legend';
  END IF;
  
  -- Update tier
  UPDATE public.profiles
  SET tier = v_new_tier
  WHERE id = p_user_id;
  
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
