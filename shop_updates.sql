-- RUN THIS IN YOUR SUPABASE SQL EDITOR
-- This ensures all users see the same shop items from the backend.

INSERT INTO shop_products (id, name, description, category, price_coins, price_gems, asset_path, is_available, sort_order)
VALUES 
  (
    'card_back_swamp', 
    'Swamp', 
    'A mystical swamp design', 
    'card_back', 
    750, 
    10, 
    'assets/card_backs/swamp.png', 
    true, 
    100
  ),
  (
    'card_back_wizard_blue', 
    'Wizard Blue', 
    'Magical blue wizardry', 
    'card_back', 
    25, 
    1, 
    'assets/card_backs/wizard_blue.png', 
    true, 
    101
  ),
  (
    'card_back_wizard_gold', 
    'Wizard Gold', 
    'Premium gold wizardry', 
    'card_back', 
    100, 
    2, 
    'assets/card_backs/wizard_gold.png', 
    true, 
    102
  ),
  (
    'card_back_doodle',
    'Doodle',
    'A rare doodle',
    'card_back',
    150,
    3,
    'assets/card_backs/doodle-rare.png',
    true,
    103
  )
ON CONFLICT (id) DO UPDATE SET
  price_coins = EXCLUDED.price_coins,
  price_gems = EXCLUDED.price_gems,
  asset_path = EXCLUDED.asset_path,
  name = EXCLUDED.name;
