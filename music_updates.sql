-- Add selected_music_id to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS selected_music_id text DEFAULT NULL;

-- Fix Shop Category Constraint
-- 1. Drop the old restrictive constraint (Allow any category)
ALTER TABLE shop_products DROP CONSTRAINT IF EXISTS shop_products_category_check;

-- Insert Music Products
INSERT INTO shop_products (id, name, description, category, price_coins, price_gems, asset_path, is_available, sort_order)
VALUES
  (
    'music_chill_techno', 
    'Chill Techno', 
    'Smooth beats for a relaxed game.', 
    'music', 
    250, 
    1, 
    'assets/background_music/chill_techno.mp3', 
    true, 
    100
  ),
  (
    'music_retro_boss_1', 
    'Retro Boss Fight 1', 
    'Intense 8-bit action music.', 
    'music', 
    250, 
    1, 
    'assets/background_music/retro_boss_fight_1.mp3', 
    true, 
    101
  ),
  (
    'music_retro_boss_2', 
    'Retro Boss Fight 2', 
    'Epic chiptune showdown.', 
    'music', 
    250, 
    1, 
    'assets/background_music/retro_boss_fight_2.mp3', 
    true, 
    102
  ),
  (
    'music_techno_pulse', 
    'Techno Pulse', 
    'High energy rhythm to keep you moving.', 
    'music', 
    250, 
    1, 
    'assets/background_music/techno_pulse.mp3', 
    true, 
    103
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price_coins = EXCLUDED.price_coins,
  price_gems = EXCLUDED.price_gems,
  asset_path = EXCLUDED.asset_path,
  category = EXCLUDED.category;
