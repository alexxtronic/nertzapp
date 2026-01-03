-- Add selected_card_back column to matchmaking_queue
-- This allows opponents to see each other's card back style during matches

ALTER TABLE public.matchmaking_queue 
ADD COLUMN IF NOT EXISTS selected_card_back TEXT;

-- Add comment for documentation
COMMENT ON COLUMN public.matchmaking_queue.selected_card_back IS 
  'Player selected card back ID for display during matches (e.g. card_back_wizard_gold)';
