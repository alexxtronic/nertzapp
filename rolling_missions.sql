-- Rolling 24-Hour Mission System
-- Run this AFTER expand_missions.sql
-- This updates the mission assignment to be user-relative (24 hours from last assignment)

-- ============================================
-- UPDATE user_missions table to track assignment time
-- ============================================

-- Change assigned_at from DATE to TIMESTAMPTZ for precise tracking
ALTER TABLE public.user_missions 
  ALTER COLUMN assigned_at TYPE TIMESTAMPTZ 
  USING assigned_at::timestamp AT TIME ZONE 'UTC';

-- Update default
ALTER TABLE public.user_missions 
  ALTER COLUMN assigned_at SET DEFAULT now();

-- ============================================
-- UPDATED FUNCTION: Assign Daily Missions (Rolling 24h)
-- Assigns missions if user has none, or if 24 hours have passed
-- ============================================

CREATE OR REPLACE FUNCTION public.assign_daily_missions(p_user_id UUID)
RETURNS SETOF public.user_missions AS $$
DECLARE
  last_assigned TIMESTAMPTZ;
  hours_since_assignment NUMERIC;
BEGIN
  -- Get the most recent mission assignment time for this user
  SELECT MAX(assigned_at) INTO last_assigned 
  FROM public.user_missions 
  WHERE user_id = p_user_id;
  
  -- Calculate hours since last assignment
  IF last_assigned IS NOT NULL THEN
    hours_since_assignment := EXTRACT(EPOCH FROM (now() - last_assigned)) / 3600;
  ELSE
    hours_since_assignment := 999; -- Force assignment for new users
  END IF;
  
  -- If less than 24 hours, return existing missions
  IF hours_since_assignment < 24 THEN
    RETURN QUERY SELECT * FROM public.user_missions 
                 WHERE user_id = p_user_id 
                 AND assigned_at = last_assigned;
    RETURN;
  END IF;
  
  -- Mark old unclaimed missions as expired (optional: could also delete)
  -- DELETE FROM public.user_missions WHERE user_id = p_user_id AND is_claimed = false;
  
  -- Assign 3 random missions (1 easy, 1 medium, 1 random difficulty)
  INSERT INTO public.user_missions (user_id, mission_id, assigned_at)
  SELECT p_user_id, id, now()
  FROM (
    (SELECT id FROM public.missions WHERE difficulty = 'easy' AND is_active = true ORDER BY RANDOM() LIMIT 1)
    UNION ALL
    (SELECT id FROM public.missions WHERE difficulty = 'medium' AND is_active = true ORDER BY RANDOM() LIMIT 1)
    UNION ALL
    (SELECT id FROM public.missions WHERE is_active = true ORDER BY RANDOM() LIMIT 1)
  ) AS selected_missions
  ON CONFLICT DO NOTHING;
  
  -- Return newly assigned missions
  RETURN QUERY SELECT * FROM public.user_missions 
               WHERE user_id = p_user_id 
               AND assigned_at >= now() - INTERVAL '1 minute';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- UPDATED: Update Mission Progress
-- Works with timestamptz instead of date
-- ============================================

CREATE OR REPLACE FUNCTION public.update_mission_progress(
  p_user_id UUID,
  p_mission_type TEXT,
  p_increment INT DEFAULT 1
)
RETURNS void AS $$
DECLARE
  last_assigned TIMESTAMPTZ;
BEGIN
  -- Get the most recent assignment time
  SELECT MAX(assigned_at) INTO last_assigned 
  FROM public.user_missions 
  WHERE user_id = p_user_id;
  
  -- Update progress for current missions
  UPDATE public.user_missions um
  SET 
    progress = LEAST(um.progress + p_increment, m.target),
    is_completed = (um.progress + p_increment >= m.target),
    completed_at = CASE WHEN (um.progress + p_increment >= m.target) AND um.completed_at IS NULL 
                        THEN now() ELSE um.completed_at END
  FROM public.missions m
  WHERE um.mission_id = m.id
    AND um.user_id = p_user_id
    AND um.assigned_at = last_assigned
    AND um.is_claimed = false
    AND m.mission_type = p_mission_type;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
