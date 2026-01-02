-- Friends & Missions System Database Schema
-- Run this in Supabase SQL Editor

-- ============================================
-- FRIENDS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.friends (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  -- Prevent duplicate friendships
  UNIQUE(user_id, friend_id)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_friends_user_id ON public.friends(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_friend_id ON public.friends(friend_id);
CREATE INDEX IF NOT EXISTS idx_friends_status ON public.friends(status);

-- RLS Policies
ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;

-- Users can view their own friendships
CREATE POLICY "Users can view own friendships" ON public.friends
  FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Users can send friend requests
CREATE POLICY "Users can send friend requests" ON public.friends
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their pending requests (accept/block)
CREATE POLICY "Users can respond to friend requests" ON public.friends
  FOR UPDATE USING (auth.uid() = friend_id AND status = 'pending');

-- Users can delete their own friendships
CREATE POLICY "Users can delete own friendships" ON public.friends
  FOR DELETE USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- ============================================
-- MISSION TEMPLATES TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.missions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT DEFAULT 'star',
  reward_coins INT NOT NULL DEFAULT 20,
  target INT NOT NULL DEFAULT 1,
  mission_type TEXT NOT NULL CHECK (mission_type IN ('win_games', 'play_games', 'challenge_friend', 'fast_win', 'nertz_calls')),
  difficulty TEXT NOT NULL DEFAULT 'easy' CHECK (difficulty IN ('easy', 'medium', 'hard')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Seed initial mission templates
INSERT INTO public.missions (name, description, reward_coins, target, mission_type, difficulty, icon) VALUES
  ('Quick Victory', 'Win 1 Nertz game', 20, 1, 'win_games', 'easy', 'emoji_events'),
  ('Getting Started', 'Play 2 games', 25, 2, 'play_games', 'easy', 'sports_esports'),
  ('Triple Threat', 'Win 3 Nertz games', 50, 3, 'win_games', 'medium', 'workspace_premium'),
  ('Social Butterfly', 'Challenge a friend to battle', 30, 1, 'challenge_friend', 'easy', 'people'),
  ('Speed Demon', 'Win a game in under 2 minutes', 75, 1, 'fast_win', 'medium', 'bolt'),
  ('Nertz Champion', 'Win 5 Nertz games', 100, 5, 'win_games', 'hard', 'military_tech'),
  ('Call Master', 'Call Nertz 3 times', 40, 3, 'nertz_calls', 'medium', 'campaign')
ON CONFLICT DO NOTHING;

-- ============================================
-- USER MISSIONS TABLE (Daily tracking)
-- ============================================

CREATE TABLE IF NOT EXISTS public.user_missions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mission_id UUID NOT NULL REFERENCES public.missions(id) ON DELETE CASCADE,
  progress INT NOT NULL DEFAULT 0,
  is_completed BOOLEAN DEFAULT false,
  is_claimed BOOLEAN DEFAULT false,
  assigned_at DATE NOT NULL DEFAULT CURRENT_DATE,
  completed_at TIMESTAMPTZ,
  claimed_at TIMESTAMPTZ,
  
  -- One mission per user per day
  UNIQUE(user_id, mission_id, assigned_at)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_missions_user_id ON public.user_missions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_missions_assigned_at ON public.user_missions(assigned_at);

-- RLS Policies
ALTER TABLE public.user_missions ENABLE ROW LEVEL SECURITY;

-- Users can view own missions
CREATE POLICY "Users view own missions" ON public.user_missions
  FOR SELECT USING (auth.uid() = user_id);

-- Users can update own mission progress
CREATE POLICY "Users update own missions" ON public.user_missions
  FOR UPDATE USING (auth.uid() = user_id);

-- System can insert missions (use service role for daily assignment)
CREATE POLICY "Allow mission assignment" ON public.user_missions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================
-- FUNCTION: Assign Daily Missions
-- ============================================

CREATE OR REPLACE FUNCTION public.assign_daily_missions(p_user_id UUID)
RETURNS SETOF public.user_missions AS $$
DECLARE
  existing_count INT;
BEGIN
  -- Check if user already has missions for today
  SELECT COUNT(*) INTO existing_count 
  FROM public.user_missions 
  WHERE user_id = p_user_id AND assigned_at = CURRENT_DATE;
  
  -- If already assigned, return existing
  IF existing_count > 0 THEN
    RETURN QUERY SELECT * FROM public.user_missions 
                 WHERE user_id = p_user_id AND assigned_at = CURRENT_DATE;
    RETURN;
  END IF;
  
  -- Assign 3 random missions (1 easy, 1 medium, 1 random)
  INSERT INTO public.user_missions (user_id, mission_id, assigned_at)
  SELECT p_user_id, id, CURRENT_DATE
  FROM (
    (SELECT id FROM public.missions WHERE difficulty = 'easy' AND is_active = true ORDER BY RANDOM() LIMIT 1)
    UNION ALL
    (SELECT id FROM public.missions WHERE difficulty = 'medium' AND is_active = true ORDER BY RANDOM() LIMIT 1)
    UNION ALL
    (SELECT id FROM public.missions WHERE is_active = true ORDER BY RANDOM() LIMIT 1)
  ) AS selected_missions
  ON CONFLICT DO NOTHING;
  
  -- Return assigned missions
  RETURN QUERY SELECT * FROM public.user_missions 
               WHERE user_id = p_user_id AND assigned_at = CURRENT_DATE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Update Mission Progress
-- ============================================

CREATE OR REPLACE FUNCTION public.update_mission_progress(
  p_user_id UUID,
  p_mission_type TEXT,
  p_increment INT DEFAULT 1
)
RETURNS void AS $$
BEGIN
  UPDATE public.user_missions um
  SET 
    progress = LEAST(um.progress + p_increment, m.target),
    is_completed = (um.progress + p_increment >= m.target),
    completed_at = CASE WHEN (um.progress + p_increment >= m.target) AND um.completed_at IS NULL 
                        THEN now() ELSE um.completed_at END
  FROM public.missions m
  WHERE um.mission_id = m.id
    AND um.user_id = p_user_id
    AND um.assigned_at = CURRENT_DATE
    AND um.is_claimed = false
    AND m.mission_type = p_mission_type;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Claim Mission Reward
-- ============================================

CREATE OR REPLACE FUNCTION public.claim_mission_reward(p_mission_id UUID)
RETURNS INT AS $$
DECLARE
  v_reward INT;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  
  -- Get reward amount and verify mission is claimable
  SELECT m.reward_coins INTO v_reward
  FROM public.user_missions um
  JOIN public.missions m ON um.mission_id = m.id
  WHERE um.id = p_mission_id
    AND um.user_id = v_user_id
    AND um.is_completed = true
    AND um.is_claimed = false;
  
  IF v_reward IS NULL THEN
    RETURN 0; -- Mission not claimable
  END IF;
  
  -- Mark as claimed
  UPDATE public.user_missions 
  SET is_claimed = true, claimed_at = now()
  WHERE id = p_mission_id;
  
  -- Add coins to user balance
  UPDATE public.profiles
  SET coins = coins + v_reward
  WHERE id = v_user_id;
  
  RETURN v_reward;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
