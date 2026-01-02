-- RUN THIS IN YOUR SUPABASE SQL EDITOR
-- Adds 3 new card backs: Icecream, Pirate, Alien

INSERT INTO shop_products (id, name, description, category, price_coins, price_gems, asset_path, is_available, sort_order)
VALUES 
  (
    'card_back_icecream', 
    'Icecream', 
    'A deliciously rare frozen treat design', 
    'card_back', 
    5000, 
    25, 
    'assets/card_backs/icecream_full.png', 
    true, 
    110
  ),
  (
    'card_back_pirate', 
    'Pirate', 
    'Arrr! Swashbuckling adventure awaits', 
    'card_back', 
    1000, 
    5, 
    'assets/card_backs/pirate_full.png', 
    true, 
    111
  ),
  (
    'card_back_alien', 
    'Alien', 
    'Out of this world extraterrestrial style', 
    'card_back', 
    1000, 
    5, 
    'assets/card_backs/alien_full.png', 
    true, 
    112
  )
ON CONFLICT (id) DO UPDATE SET
  price_coins = EXCLUDED.price_coins,
  price_gems = EXCLUDED.price_gems,
  asset_path = EXCLUDED.asset_path,
  name = EXCLUDED.name,
  description = EXCLUDED.description;
