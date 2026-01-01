-- Add selected_background_id to profiles if not exists
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS selected_background_id UUID REFERENCES public.shop_products(id);

-- Drop category check constraint if it exists strictly (we already relaxed it for music, but just in case)
-- Note: We did this in music_updates.sql, allowing any text.

-- Insert Background Products
INSERT INTO public.shop_products (id, name, description, price_coins, price_gems, category, asset_path, is_available)
VALUES 
  ('bg_galaxy', 'Galaxy', 'Deep space vibes for your game.', 200, 0, 'board', 'assets/backgrounds/galaxy.png', true),
  ('bg_sunset', 'Sunset', 'Warm and relaxing sunset gradient.', 50, 0, 'board', 'assets/backgrounds/sunset.png', true),
  ('bg_sky', 'Sky', 'Bright blue sky with fluffy clouds.', 50, 0, 'board', 'assets/backgrounds/sky.png', true),
  ('bg_grass', 'Grass', 'Fresh green grass texture.', 50, 0, 'board', 'assets/backgrounds/grass.png', true),
  ('bg_flowers', 'Flowers', 'Soft floral pattern.', 100, 0, 'board', 'assets/backgrounds/flowers.png', true),
  ('bg_peach_glow', 'Peach Glow', 'Warm peach gradient with soft glow.', 5, 0, 'board', 'assets/backgrounds/peach_glow.png', true)
ON CONFLICT (id) DO NOTHING;
