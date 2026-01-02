-- Fix RLS policy for accepting friend requests
-- The receiver (friend_id) needs permission to update the status to 'accepted'

-- First, check existing policies (run this manually to see current state)
-- SELECT * FROM pg_policies WHERE tablename = 'friends';

-- Allow the receiver (friend_id) to update the status of pending requests to 'accepted'
CREATE POLICY "Receiver can accept friend request"
ON public.friends
FOR UPDATE
USING (
  friend_id = auth.uid() AND status = 'pending'
)
WITH CHECK (
  friend_id = auth.uid() AND status = 'accepted'
);

-- Also ensure both parties can view the friendship
CREATE POLICY "Users can view their friendships"
ON public.friends
FOR SELECT
USING (
  user_id = auth.uid() OR friend_id = auth.uid()
);

-- Ensure senders can update/delete their own pending requests (if not already exists)
CREATE POLICY "Sender can manage their requests"
ON public.friends
FOR ALL
USING (
  user_id = auth.uid()
);

-- If policies already exist and you need to replace them, run:
-- DROP POLICY IF EXISTS "Receiver can accept friend request" ON public.friends;
-- Then re-run the CREATE POLICY statement above.
