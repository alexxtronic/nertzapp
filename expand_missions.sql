-- Expanded Daily Missions System
-- Run this in Supabase SQL Editor

-- ============================================
-- DELETE OLD MISSIONS (to reset with new set)
-- ============================================
DELETE FROM public.user_missions;
DELETE FROM public.missions;

-- ============================================
-- INSERT 18 MISSION TEMPLATES
-- Difficulty-based coin rewards:
--   Easy (10-25 coins): Simple, achievable in 1-2 games
--   Medium (30-60 coins): Requires effort, 2-4 games
--   Hard (75-150 coins): Challenge, 4+ games or specific skill
-- ============================================

INSERT INTO public.missions (name, description, reward_coins, target, mission_type, difficulty, icon) VALUES
  -- EASY (10-25 coins) - Quick, achievable goals
  ('First Win', 'Win 1 Nertz game', 15, 1, 'win_games', 'easy', 'emoji_events'),
  ('Warm Up', 'Play 1 game', 10, 1, 'play_games', 'easy', 'sports_esports'),
  ('Getting Started', 'Play 2 games', 20, 2, 'play_games', 'easy', 'sports_esports'),
  ('Friendly Match', 'Challenge a friend to a game', 25, 1, 'challenge_friend', 'easy', 'people'),
  ('Nertz!', 'Call Nertz once', 15, 1, 'nertz_calls', 'easy', 'campaign'),
  ('Double Up', 'Win 2 games', 25, 2, 'win_games', 'easy', 'emoji_events'),
  
  -- MEDIUM (30-60 coins) - Moderate effort
  ('Triple Threat', 'Win 3 games', 40, 3, 'win_games', 'medium', 'workspace_premium'),
  ('Marathon Runner', 'Play 5 games', 35, 5, 'play_games', 'medium', 'directions_run'),
  ('Speed Demon', 'Win a game in under 2 minutes', 50, 1, 'fast_win', 'medium', 'bolt'),
  ('Call Master', 'Call Nertz 3 times', 40, 3, 'nertz_calls', 'medium', 'campaign'),
  ('Social Gamer', 'Challenge 2 different friends', 45, 2, 'challenge_friend', 'medium', 'group'),
  ('Consistent Player', 'Play 4 games', 30, 4, 'play_games', 'medium', 'schedule'),
  ('Winning Streak', 'Win 4 games', 55, 4, 'win_games', 'medium', 'trending_up'),
  
  -- HARD (75-150 coins) - Significant challenge
  ('Nertz Champion', 'Win 5 games', 75, 5, 'win_games', 'hard', 'military_tech'),
  ('Endurance Test', 'Play 8 games', 60, 8, 'play_games', 'hard', 'fitness_center'),
  ('Lightning Fast', 'Win 2 games in under 2 minutes each', 100, 2, 'fast_win', 'hard', 'flash_on'),
  ('Nertz Master', 'Call Nertz 5 times', 80, 5, 'nertz_calls', 'hard', 'star'),
  ('Domination', 'Win 7 games', 150, 7, 'win_games', 'hard', 'whatshot')
ON CONFLICT DO NOTHING;

-- ============================================
-- VERIFY MISSIONS INSERTED
-- ============================================
SELECT name, difficulty, reward_coins, target, mission_type FROM public.missions ORDER BY difficulty, reward_coins;
