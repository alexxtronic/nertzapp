-- Economy RPC Functions for IAP and Rewards
-- Run this in Supabase SQL Editor

-- Function to safely add coins
CREATE OR REPLACE FUNCTION public.add_coins(user_id UUID, amount INT)
RETURNS void AS $$
BEGIN
  UPDATE public.profiles
  SET coins = coins + amount
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to safely add gems
CREATE OR REPLACE FUNCTION public.add_gems(user_id UUID, amount INT)
RETURNS void AS $$
BEGIN
  UPDATE public.profiles
  SET gems = gems + amount
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users (so the app can call them)
-- Note: In a real production app, you might restrict this more or rely on server-side verification callbacks
GRANT EXECUTE ON FUNCTION public.add_coins(UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_gems(UUID, INT) TO authenticated;
