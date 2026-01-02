-- Update music prices to 250 Coins / 1 Gem as requested
UPDATE shop_products
SET 
  price_coins = 250,
  price_gems = 1
WHERE category = 'music';
