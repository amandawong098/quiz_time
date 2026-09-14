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

-- 5. Prevent duplicate reports from the same learner (including across dismissed/resolved statuses)
-- Clean up any existing duplicate topic reports before adding unique index (keeping the earliest report)
DELETE FROM public.discussion_reports a
USING public.discussion_reports b
WHERE a.id > b.id
  AND a.reporter_id = b.reporter_id
  AND a.topic_id = b.topic_id
  AND a.reply_id IS NULL
  AND b.reply_id IS NULL;

-- Clean up any existing duplicate reply reports before adding unique index (keeping the earliest report)
DELETE FROM public.discussion_reports a
USING public.discussion_reports b
WHERE a.id > b.id
  AND a.reporter_id = b.reporter_id
  AND a.reply_id IS NOT NULL
  AND a.reply_id = b.reply_id;

-- Unique partial index for topic-level reports (one report per topic per learner)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_learner_topic_report 
ON public.discussion_reports (reporter_id, topic_id) 
WHERE reply_id IS NULL;

-- Unique partial index for reply reports (one report per reply per learner)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_learner_reply_report 
ON public.discussion_reports (reporter_id, reply_id) 
WHERE reply_id IS NOT NULL;

-- Note: To make your user an Admin, run:
-- UPDATE public.profiles SET role = 'admin' WHERE email = 'your_email@example.com';

-- =======================================================
-- 6. EXCLUDE ADMINS FROM LEADERBOARD & AUTO RESET FOR ALL LEARNERS
-- =======================================================

-- Clear league and weekly_xp for any existing admin profiles so they never participate in leagues
UPDATE public.profiles 
SET league = NULL, weekly_xp = 0 
WHERE LOWER(COALESCE(role, 'learner')) = 'admin';

-- Recreate reset_weekly_leagues to strictly exclude admins and auto-process all learners globally
CREATE OR REPLACE FUNCTION public.reset_weekly_leagues()
RETURNS void AS $$
DECLARE
    league_rec RECORD;
    user_rec RECORD;
    total_users INTEGER;
    promo_count INTEGER;
    demo_count INTEGER;
    user_rank INTEGER;
    next_league_name TEXT;
    prev_league_name TEXT;
    min_xp INTEGER;
    promo_pct DOUBLE PRECISION;
    demo_pct DOUBLE PRECISION;
    v_new_league TEXT;
    v_title TEXT;
    v_msg TEXT;
    v_type TEXT;
BEGIN
    -- Clean up admin profiles so admins never participate in leaderboard rankings
    UPDATE public.profiles
    SET league = NULL, weekly_xp = 0
    WHERE LOWER(COALESCE(role, 'learner')) = 'admin';

    -- Create temporary table to store updates
    CREATE TEMP TABLE temp_league_updates (
        user_id UUID PRIMARY KEY,
        new_league TEXT,
        old_league TEXT
    ) ON COMMIT DROP;

    -- Iterate through leagues sorted by order
    FOR league_rec IN 
        SELECT league, rank_order, min_weekly_xp, promotion_pct, demotion_pct
        FROM public.league_configs
        ORDER BY rank_order ASC
    LOOP
        -- Count users currently in this league (learners only, strictly excluding admins)
        SELECT COUNT(*) INTO total_users 
        FROM public.profiles 
        WHERE league = league_rec.league
          AND LOWER(COALESCE(role, 'learner')) != 'admin';

        IF total_users > 0 THEN
            promo_pct := league_rec.promotion_pct;
            demo_pct := league_rec.demotion_pct;
            min_xp := league_rec.min_weekly_xp;

            -- Ceiling rounding ensures that even in small lists, at least 1 person can be promoted/demoted
            promo_count := CEIL(total_users * promo_pct);
            demo_count := CEIL(total_users * demo_pct);

            user_rank := 0;
            -- Fetch all users in this league sorted by weekly_xp desc (learners only, strictly excluding admins)
            FOR user_rec IN 
                SELECT id, weekly_xp 
                FROM public.profiles 
                WHERE league = league_rec.league
                  AND LOWER(COALESCE(role, 'learner')) != 'admin'
                ORDER BY weekly_xp DESC, updated_at ASC, id ASC
            LOOP
                user_rank := user_rank + 1;
                v_new_league := league_rec.league;

                -- Promotion logic: top rank within top% and met min weekly XP
                IF user_rank <= promo_count AND user_rec.weekly_xp >= min_xp THEN
                    SELECT league INTO next_league_name 
                    FROM public.league_configs 
                    WHERE rank_order = league_rec.rank_order + 1;

                    IF next_league_name IS NOT NULL THEN
                        v_new_league := next_league_name;
                    END IF;
                
                -- Demotion logic: bottom rank within bottom% and failed to meet min weekly XP
                ELSIF user_rank > (total_users - demo_count) AND user_rec.weekly_xp < min_xp THEN
                    SELECT league INTO prev_league_name 
                    FROM public.league_configs 
                    WHERE rank_order = league_rec.rank_order - 1;

                    IF prev_league_name IS NOT NULL THEN
                        v_new_league := prev_league_name;
                    END IF;
                END IF;

                -- Save to updates table
                INSERT INTO temp_league_updates (user_id, new_league, old_league)
                VALUES (user_rec.id, v_new_league, league_rec.league);
            END LOOP;
        END IF;
    END LOOP;

    -- Apply promotions/demotions and send notifications to all learners
    FOR user_rec IN SELECT user_id, new_league, old_league FROM temp_league_updates LOOP
        IF user_rec.new_league <> user_rec.old_league THEN
            UPDATE public.profiles
            SET league = user_rec.new_league
            WHERE id = user_rec.user_id;

            IF (SELECT rank_order FROM public.league_configs WHERE league = user_rec.new_league) > 
               (SELECT rank_order FROM public.league_configs WHERE league = user_rec.old_league) THEN
                v_title := 'League Promotion!';
                v_msg := 'Outstanding effort! You have been promoted to the ' || user_rec.new_league || ' league. Keep pushing your boundaries and climb higher!';
                v_type := 'league_promotion';
            ELSE
                v_title := 'League Demotion';
                v_msg := 'You have moved to the ' || user_rec.new_league || ' league. Do not give up! Jump back into learning to reclaim your rank!';
                v_type := 'league_demotion';
            END IF;
        ELSE
            v_title := 'League Division Retained';
            v_msg := 'Solid performance! You have retained your spot in the ' || user_rec.new_league || ' league. Aim even higher in the new weekly cycle!';
            v_type := 'league_stay';
        END IF;

        INSERT INTO public.notifications (user_id, title, message, type, is_read, created_at)
        VALUES (user_rec.user_id, v_title, v_msg, v_type, false, NOW());
    END LOOP;

    -- Reset weekly XP for all users back to 0 in both profiles and auth.users metadata
    UPDATE public.profiles
    SET weekly_xp = 0
    WHERE id IS NOT NULL;

    UPDATE auth.users
    SET raw_user_meta_data = jsonb_set(COALESCE(raw_user_meta_data, '{}'::jsonb), '{weekly_xp}', '0'::jsonb)
    WHERE id IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Optional pg_cron automated server-side weekly execution (runs every Sunday at 00:00:00 UTC):
-- SELECT cron.schedule('weekly-league-reset', '0 0 * * 0', 'SELECT public.check_and_reset_weekly_leagues(true);');


