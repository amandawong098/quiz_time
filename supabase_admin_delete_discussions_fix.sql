-- ========================================================
-- LearnByte: Fix Admin Deletion for Discussion Topics & Replies
-- Run this script in your Supabase Dashboard SQL Editor
-- ========================================================

-- 1. DISCUSSION TOPICS: Allow Admins to delete any topic
DROP POLICY IF EXISTS "Admins can delete any topic" ON public.discussion_topics;
CREATE POLICY "Admins can delete any topic" 
ON public.discussion_topics 
FOR DELETE 
USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.id = auth.uid() 
        AND LOWER(COALESCE(profiles.role, 'learner')) = 'admin'
    )
);

-- 2. DISCUSSION REPLIES: Allow Admins to delete any reply
DROP POLICY IF EXISTS "Admins can delete any reply" ON public.discussion_replies;
CREATE POLICY "Admins can delete any reply" 
ON public.discussion_replies 
FOR DELETE 
USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE profiles.id = auth.uid() 
        AND LOWER(COALESCE(profiles.role, 'learner')) = 'admin'
    )
);

-- 3. Dedicated SECURITY DEFINER RPC to delete discussion topics as admin
-- Bypasses RLS safely after strictly verifying the caller has role = 'admin'
CREATE OR REPLACE FUNCTION public.admin_delete_discussion_topic(p_topic_id UUID)
RETURNS void AS $$
BEGIN
    -- Verify caller is an administrator
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() 
        AND LOWER(COALESCE(role, 'learner')) = 'admin'
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators can delete topics';
    END IF;

    -- Delete any reports associated with this topic first
    DELETE FROM public.discussion_reports WHERE topic_id = p_topic_id;

    -- Delete discussion topic (cascades to replies, topic_votes, etc.)
    DELETE FROM public.discussion_topics WHERE id = p_topic_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Dedicated SECURITY DEFINER RPC to delete discussion replies as admin
CREATE OR REPLACE FUNCTION public.admin_delete_discussion_reply(p_reply_id UUID)
RETURNS void AS $$
BEGIN
    -- Verify caller is an administrator
    IF NOT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() 
        AND LOWER(COALESCE(role, 'learner')) = 'admin'
    ) THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators can delete replies';
    END IF;

    -- Delete any reports associated with this reply first
    DELETE FROM public.discussion_reports WHERE reply_id = p_reply_id;

    -- Delete reply (cascades to reply_votes, etc.)
    DELETE FROM public.discussion_replies WHERE id = p_reply_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.admin_delete_discussion_topic(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_discussion_reply(UUID) TO authenticated;
