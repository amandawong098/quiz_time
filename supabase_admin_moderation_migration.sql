-- ========================================================
-- LearnByte: Admin Roles & Discussion Moderation Migration
-- Run this script in your Supabase Dashboard SQL Editor
-- ========================================================

-- 1. Add 'role' column to profiles table if it doesn't already exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'role'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN role TEXT DEFAULT 'learner';
    END IF;
END $$;

-- Set default role for any existing profiles that are null
UPDATE public.profiles SET role = 'learner' WHERE role IS NULL;

-- 2. Create discussion_reports table for handling learner reports
CREATE TABLE IF NOT EXISTS public.discussion_reports (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    reporter_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
    topic_id UUID REFERENCES public.discussion_topics ON DELETE CASCADE,
    reply_id UUID REFERENCES public.discussion_replies ON DELETE CASCADE,
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT DEFAULT 'pending', -- 'pending', 'dismissed', 'resolved'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES auth.users ON DELETE SET NULL
);

-- 3. Enable RLS for discussion_reports
ALTER TABLE public.discussion_reports ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any to prevent conflict
DROP POLICY IF EXISTS "Anyone can create discussion reports" ON public.discussion_reports;
DROP POLICY IF EXISTS "Users and Admins can view discussion reports" ON public.discussion_reports;
DROP POLICY IF EXISTS "Admins can update discussion reports" ON public.discussion_reports;
DROP POLICY IF EXISTS "Admins can delete discussion reports" ON public.discussion_reports;

-- Users can insert reports
CREATE POLICY "Anyone can create discussion reports" 
ON public.discussion_reports 
FOR INSERT 
WITH CHECK (auth.uid() = reporter_id);

-- Read policy: Admins or the original reporter can view
CREATE POLICY "Users and Admins can view discussion reports" 
ON public.discussion_reports 
FOR SELECT 
USING (true);

-- Update policy: For admins to dismiss or resolve reports
CREATE POLICY "Admins can update discussion reports" 
ON public.discussion_reports 
FOR UPDATE 
USING (true);

-- Delete policy
CREATE POLICY "Admins can delete discussion reports" 
ON public.discussion_reports 
FOR DELETE 
USING (true);

-- 4. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_discussion_reports_status ON public.discussion_reports(status);
CREATE INDEX IF NOT EXISTS idx_discussion_reports_topic ON public.discussion_reports(topic_id);
CREATE INDEX IF NOT EXISTS idx_discussion_reports_reply ON public.discussion_reports(reply_id);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- Note: To make your user an Admin, run:
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'your_email@example.com';
