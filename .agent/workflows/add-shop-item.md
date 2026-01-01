---
description: Add item to the Nertz Royale shop (card backs, backgrounds, music)
---

# Adding Shop Products to Supabase

When adding new purchaseable items to the shop, use this SQL pattern:

```sql
INSERT INTO public.shop_products (id, name, description, price_coins, price_gems, category, asset_path, is_available)
VALUES ('unique_id', 'Display Name', 'Description text', 5, 0, 'category', 'assets/path/to/file.png', true)
ON CONFLICT (id) DO NOTHING;
```

## Required Fields
- **id**: Explicit string ID (NOT auto-generated) - use format like `bg_peach_glow`, `card_back_wizard`
- **name**: Display name in shop
- **description**: Item description
- **price_coins**: Integer coin cost
- **price_gems**: Integer gem cost (use 0 if coins only)
- **category**: One of: `card_back`, `board`, `music`
- **asset_path**: Local asset path like `assets/backgrounds/filename.png`
- **is_available**: `true` to show in shop (NOT `is_active`)

## Steps
1. Copy asset to appropriate folder:
   - Card backs: `assets/card_backs/`
   - Backgrounds: `assets/backgrounds/`
   - Music: `assets/background_music/`

2. Run SQL in Supabase SQL Editor

3. Update the corresponding SQL file for future reference:
   - `shop_updates.sql` for card backs
   - `background_updates.sql` for backgrounds
   - `music_updates.sql` for music
