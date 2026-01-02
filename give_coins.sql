-- RUN THIS IN YOUR SUPABASE SQL EDITOR
-- Adds 10,000 coins to the account skalex3@yahoo.com using the add_coins RPC

-- Call the add_coins function with the user's ID
SELECT public.add_coins(
  (SELECT id FROM auth.users WHERE email = 'skalex3@yahoo.com'),
  10000
);

-- Verify the update
SELECT username, coins, gems 
FROM profiles 
WHERE id = (SELECT id FROM auth.users WHERE email = 'skalex3@yahoo.com');
