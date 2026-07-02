-- ==========================================
-- QUIZTIME SUPABASE COMPLETE SCHEMA
-- ==========================================

-- 1. CLEANUP (DROP EVERYTHING CASCADE)
-- This ensures a fresh start for a new user.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP TRIGGER IF EXISTS update_quiz_question_count_trigger ON public.questions CASCADE;
DROP FUNCTION IF EXISTS public.update_quiz_question_count() CASCADE;
DROP FUNCTION IF EXISTS public.delete_user() CASCADE;

DROP TABLE IF EXISTS public.options CASCADE;
DROP TABLE IF EXISTS public.questions CASCADE;
DROP TABLE IF EXISTS public.quiz_attempts CASCADE;
DROP TABLE IF EXISTS public.quizzes CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.subjects CASCADE;
DROP TABLE IF EXISTS public.grades CASCADE;
DROP TABLE IF EXISTS public.lesson_blocks CASCADE;
DROP TABLE IF EXISTS public.lesson_pages CASCADE;
DROP TABLE IF EXISTS public.lesson_sub_chapters CASCADE;
DROP TABLE IF EXISTS public.lesson_chapters CASCADE;
DROP TABLE IF EXISTS public.lesson_courses CASCADE;

-- 2. CREATE TABLES

-- Profiles Table (Extension of Auth.Users)
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    email TEXT,
    name TEXT,
    avatar_url TEXT,
    xp INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Subjects Table (For localized dropdowns)
CREATE TABLE public.subjects (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Grades Table (For localized dropdowns)
CREATE TABLE public.grades (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Quizzes Table
CREATE TABLE public.quizzes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    creator_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    grade TEXT,
    subject TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    image_url TEXT,
    question_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Questions Table
CREATE TABLE public.questions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    quiz_id UUID REFERENCES public.quizzes ON DELETE CASCADE NOT NULL,
    question_text TEXT NOT NULL,
    duration_seconds INTEGER DEFAULT 30,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Options Table
CREATE TABLE public.options (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    question_id UUID REFERENCES public.questions ON DELETE CASCADE NOT NULL,
    option_text TEXT NOT NULL,
    is_correct BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Quiz Attempts Table (History)
CREATE TABLE public.quiz_attempts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
    quiz_id UUID REFERENCES public.quizzes ON DELETE CASCADE NOT NULL,
    score INTEGER NOT NULL,
    total_questions INTEGER NOT NULL,
    correct_answers INTEGER NOT NULL,
    wrong_answers INTEGER NOT NULL,
    avg_time_per_question DOUBLE PRECISION,
    user_answers JSONB DEFAULT '[]'::JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. FUNCTIONS & TRIGGERS

-- Handle New User Profile Creation
-- Automatically creates a profile entry when a user signs up via Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, name, xp, weekly_xp, league)
    VALUES (new.id, new.email, new.raw_user_meta_data->>'name', 0, 0, 'Stargazer');
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Handle Profile updates on user metadata changes
CREATE OR REPLACE FUNCTION public.handle_update_user() 
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET 
        name = COALESCE(new.raw_user_meta_data->>'name', name),
        avatar_url = COALESCE(new.raw_user_meta_data->>'avatar_url', avatar_url),
        email = COALESCE(new.email, email),
        xp = COALESCE((new.raw_user_meta_data->>'xp')::integer, xp),
        weekly_xp = COALESCE((new.raw_user_meta_data->>'weekly_xp')::integer, weekly_xp),
        league = COALESCE(new.raw_user_meta_data->>'league', league),
        updated_at = NOW()
    WHERE id = new.id;
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_updated
    AFTER UPDATE ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_update_user();

-- Maintain Question Count on Quizzes
-- Automatically increments/decrements question_count when questions are added/removed
CREATE OR REPLACE FUNCTION public.update_quiz_question_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.quizzes 
        SET question_count = question_count + 1 
        WHERE id = NEW.quiz_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.quizzes 
        SET question_count = question_count - 1 
        WHERE id = OLD.quiz_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_quiz_question_count_trigger
    AFTER INSERT OR DELETE ON public.questions
    FOR EACH ROW EXECUTE PROCEDURE public.update_quiz_question_count();

-- RPC Function for User Self-Deletion
-- Required for the "Delete Account" feature to work correctly
CREATE OR REPLACE FUNCTION public.delete_user()
RETURNS void AS $$
BEGIN
    DELETE FROM auth.users WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. INITIAL DATA SEEDING

INSERT INTO public.subjects (name) VALUES 
('Maths'), ('Science'), ('Computing'), ('History'), ('Geography'), ('Art'), ('Other')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.grades (name) VALUES 
('Kindergarten'), ('Grade 1'), ('Grade 2'), ('Grade 3'), ('Grade 4'), ('Grade 5'), ('Grade 6'), 
('Grade 7'), ('Grade 8'), ('Grade 9'), ('Grade 10'), ('Grade 11'), ('Grade 12'), ('University')
ON CONFLICT (name) DO NOTHING;

-- 5. ROW LEVEL SECURITY (RLS)

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Subjects & Grades Policies (Read only for public)
CREATE POLICY "Public read subjects" ON public.subjects FOR SELECT USING (true);
CREATE POLICY "Public read grades" ON public.grades FOR SELECT USING (true);

-- Quizzes Policies
CREATE POLICY "Viewable quizzes" ON public.quizzes FOR SELECT USING (is_public = true OR auth.uid() = creator_id);
CREATE POLICY "Insert own quizzes" ON public.quizzes FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Update own quizzes" ON public.quizzes FOR UPDATE USING (auth.uid() = creator_id);
CREATE POLICY "Delete own quizzes" ON public.quizzes FOR DELETE USING (auth.uid() = creator_id);

-- Questions Policies
CREATE POLICY "Viewable questions" ON public.questions FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.quizzes WHERE id = quiz_id AND (is_public = true OR auth.uid() = creator_id))
);
CREATE POLICY "Manage own questions" ON public.questions FOR ALL USING (
    EXISTS (SELECT 1 FROM public.quizzes WHERE id = quiz_id AND auth.uid() = creator_id)
);

-- Options Policies
CREATE POLICY "Viewable options" ON public.options FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.questions q JOIN public.quizzes z ON q.quiz_id = z.id WHERE q.id = question_id AND (z.is_public = true OR auth.uid() = z.creator_id))
);
CREATE POLICY "Manage own options" ON public.options FOR ALL USING (
    EXISTS (SELECT 1 FROM public.questions q JOIN public.quizzes z ON q.quiz_id = z.id WHERE q.id = question_id AND auth.uid() = z.creator_id)
);

-- Quiz Attempts Policies
CREATE POLICY "View own attempts" ON public.quiz_attempts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Insert own attempts" ON public.quiz_attempts FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 6. STORAGE CONFIGURATION
-- Run these to set up the necessary buckets and permissions for images.

-- Create Buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('profile_pictures', 'profile_pictures', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('quiz_images', 'quiz_images', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('lesson_images', 'lesson_images', true) ON CONFLICT (id) DO NOTHING;

-- Storage Policies for 'profile_pictures'
CREATE POLICY "Public Read Profile Pics" ON storage.objects FOR SELECT USING (bucket_id = 'profile_pictures');
CREATE POLICY "Auth Insert Profile Pics" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'profile_pictures' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Update Profile Pics" ON storage.objects FOR UPDATE USING (bucket_id = 'profile_pictures' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Delete Profile Pics" ON storage.objects FOR DELETE USING (bucket_id = 'profile_pictures' AND auth.role() = 'authenticated');

-- Storage Policies for 'quiz_images'
CREATE POLICY "Public Read Quiz Images" ON storage.objects FOR SELECT USING (bucket_id = 'quiz_images');
CREATE POLICY "Auth Insert Quiz Images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'quiz_images' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Update Quiz Images" ON storage.objects FOR UPDATE USING (bucket_id = 'quiz_images' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Delete Quiz Images" ON storage.objects FOR DELETE USING (bucket_id = 'quiz_images' AND auth.role() = 'authenticated');

-- Storage Policies for 'lesson_images'
CREATE POLICY "Public Read Lesson Images" ON storage.objects FOR SELECT USING (bucket_id = 'lesson_images');
CREATE POLICY "Auth Insert Lesson Images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'lesson_images' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Update Lesson Images" ON storage.objects FOR UPDATE USING (bucket_id = 'lesson_images' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Delete Lesson Images" ON storage.objects FOR DELETE USING (bucket_id = 'lesson_images' AND auth.role() = 'authenticated');

-- =======================================================
-- 7. DISCUSSIONS SCHEMA WITH VOTING SYSTEM & THREADED COMMENTS
-- =======================================================

CREATE TABLE IF NOT EXISTS public.discussion_topics (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    tag TEXT DEFAULT 'General',
    attachments JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.discussion_replies (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    topic_id UUID REFERENCES public.discussion_topics ON DELETE CASCADE NOT NULL,
    author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    attachments JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    parent_id UUID REFERENCES public.discussion_replies(id) ON DELETE CASCADE,
    reply_to_id UUID REFERENCES public.discussion_replies(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.topic_votes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    topic_id UUID REFERENCES public.discussion_topics ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    vote_type INTEGER NOT NULL, -- 1 for upvote, -1 for downvote
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (topic_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.reply_votes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    reply_id UUID REFERENCES public.discussion_replies ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    vote_type INTEGER NOT NULL, -- 1 for upvote, -1 for downvote
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (reply_id, user_id)
);

-- Enable RLS for Security
ALTER TABLE public.discussion_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discussion_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.topic_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reply_votes ENABLE ROW LEVEL SECURITY;

-- Policies for Discussion Topics
CREATE POLICY "Public read topics" ON public.discussion_topics FOR SELECT USING (true);
CREATE POLICY "Insert own topics" ON public.discussion_topics FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Update own topics" ON public.discussion_topics FOR UPDATE USING (auth.uid() = author_id);
CREATE POLICY "Delete own topics" ON public.discussion_topics FOR DELETE USING (auth.uid() = author_id);

-- Policies for Discussion Replies
CREATE POLICY "Public read replies" ON public.discussion_replies FOR SELECT USING (true);
CREATE POLICY "Insert own replies" ON public.discussion_replies FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Update own replies" ON public.discussion_replies FOR UPDATE USING (auth.uid() = author_id);
CREATE POLICY "Delete own replies" ON public.discussion_replies FOR DELETE USING (auth.uid() = author_id);

-- Policies for Topic Votes
CREATE POLICY "Public read topic votes" ON public.topic_votes FOR SELECT USING (true);
CREATE POLICY "Insert own topic votes" ON public.topic_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Update own topic votes" ON public.topic_votes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Delete own topic votes" ON public.topic_votes FOR DELETE USING (auth.uid() = user_id);

-- Policies for Reply Votes
CREATE POLICY "Public read reply votes" ON public.reply_votes FOR SELECT USING (true);
CREATE POLICY "Insert own reply votes" ON public.reply_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Update own reply votes" ON public.reply_votes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Delete own reply votes" ON public.reply_votes FOR DELETE USING (auth.uid() = user_id);

-- Discussion Storage Bucket for attachments (Public)
INSERT INTO storage.buckets (id, name, public) VALUES ('discussion_attachments', 'discussion_attachments', true) ON CONFLICT (id) DO NOTHING;

-- Storage Policies for 'discussion_attachments'
CREATE POLICY "Public Read Discussion Attachments" ON storage.objects FOR SELECT USING (bucket_id = 'discussion_attachments');
CREATE POLICY "Auth Insert Discussion Attachments" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'discussion_attachments' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Delete Discussion Attachments" ON storage.objects FOR DELETE USING (bucket_id = 'discussion_attachments' AND auth.role() = 'authenticated');

-- =======================================================
-- 8. FRIENDSHIP & NOTIFICATION SCHEMA
-- =======================================================

CREATE TABLE IF NOT EXISTS public.friendships (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (sender_id, receiver_id)
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view friendships involving them" ON public.friendships 
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can insert friendships where they are the sender" ON public.friendships 
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update friendships involving them" ON public.friendships 
    FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can delete friendships involving them" ON public.friendships 
    FOR DELETE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can view own notifications" ON public.notifications 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON public.notifications 
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications" ON public.notifications 
    FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can insert notifications" ON public.notifications
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- =======================================================
-- 9. MULTIPLAYER QUIZ CHALLENGES
-- =======================================================

-- Sync active and playing states on profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_playing BOOLEAN DEFAULT FALSE;

-- Quiz Challenges Table
CREATE TABLE IF NOT EXISTS public.quiz_challenges (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE NOT NULL,
    host_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'started', 'completed', 'cancelled')),
    shuffle BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Quiz Challenge Players Table
CREATE TABLE IF NOT EXISTS public.quiz_challenge_players (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    challenge_id UUID REFERENCES public.quiz_challenges(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'timeout')),
    score INTEGER DEFAULT 0,
    accuracy DOUBLE PRECISION DEFAULT 0.0,
    completed_at TIMESTAMPTZ,
    is_quit BOOLEAN DEFAULT FALSE,
    UNIQUE (challenge_id, user_id)
);

-- Enable RLS
ALTER TABLE public.quiz_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_challenge_players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow select challenges" ON public.quiz_challenges FOR SELECT USING (true);
CREATE POLICY "Allow insert own challenges" ON public.quiz_challenges FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY "Allow update challenges" ON public.quiz_challenges FOR UPDATE USING (true);

CREATE POLICY "Allow select players" ON public.quiz_challenge_players FOR SELECT USING (true);
CREATE POLICY "Allow insert own players" ON public.quiz_challenge_players FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow update players" ON public.quiz_challenge_players FOR UPDATE USING (true);

-- Enable Realtime Replication
ALTER PUBLICATION supabase_realtime ADD TABLE public.quiz_challenges;
ALTER PUBLICATION supabase_realtime ADD TABLE public.quiz_challenge_players;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;

-- =======================================================
-- 10. INTERACTIVE LESSONS & BLOCK CREATOR
-- =======================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Lesson Courses Table
CREATE TABLE IF NOT EXISTS public.lesson_courses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    image_url TEXT,
    creator_id UUID REFERENCES auth.users ON DELETE CASCADE DEFAULT auth.uid(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lesson Chapters Table
CREATE TABLE IF NOT EXISTS public.lesson_chapters (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course_id UUID REFERENCES public.lesson_courses(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lesson Sub-chapters Table
CREATE TABLE IF NOT EXISTS public.lesson_sub_chapters (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    chapter_id UUID REFERENCES public.lesson_chapters(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    xp_reward INTEGER DEFAULT 10,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lesson Pages Table
CREATE TABLE IF NOT EXISTS public.lesson_pages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    sub_chapter_id UUID REFERENCES public.lesson_sub_chapters(id) ON DELETE CASCADE NOT NULL,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lesson Blocks Table
CREATE TABLE IF NOT EXISTS public.lesson_blocks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    page_id UUID REFERENCES public.lesson_pages(id) ON DELETE CASCADE NOT NULL,
    block_type TEXT NOT NULL CHECK (block_type IN ('text', 'media', 'test', 'file')),
    content JSONB NOT NULL,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.lesson_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_sub_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_blocks ENABLE ROW LEVEL SECURITY;

-- Allow select to everyone if public, or if creator
CREATE POLICY "Viewable courses" ON public.lesson_courses FOR SELECT USING (is_public = true OR auth.uid() = creator_id);
CREATE POLICY "Insert own courses" ON public.lesson_courses FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Update own courses" ON public.lesson_courses FOR UPDATE USING (auth.uid() = creator_id);
CREATE POLICY "Delete own courses" ON public.lesson_courses FOR DELETE USING (auth.uid() = creator_id);

-- Policies for chapters
CREATE POLICY "Viewable chapters" ON public.lesson_chapters FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.lesson_courses WHERE id = course_id AND (is_public = true OR auth.uid() = creator_id))
);
CREATE POLICY "Manage own chapters" ON public.lesson_chapters FOR ALL USING (
    NOT EXISTS (SELECT 1 FROM public.lesson_courses WHERE id = course_id) OR
    EXISTS (SELECT 1 FROM public.lesson_courses WHERE id = course_id AND auth.uid() = creator_id)
);

-- Policies for sub_chapters
CREATE POLICY "Viewable sub_chapters" ON public.lesson_sub_chapters FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.lesson_chapters c JOIN public.lesson_courses o ON c.course_id = o.id WHERE c.id = chapter_id AND (o.is_public = true OR auth.uid() = o.creator_id))
);
CREATE POLICY "Manage own sub_chapters" ON public.lesson_sub_chapters FOR ALL USING (
    NOT EXISTS (SELECT 1 FROM public.lesson_chapters WHERE id = chapter_id) OR
    EXISTS (SELECT 1 FROM public.lesson_chapters c JOIN public.lesson_courses o ON c.course_id = o.id WHERE c.id = chapter_id AND auth.uid() = o.creator_id)
);

-- Policies for pages
CREATE POLICY "Viewable pages" ON public.lesson_pages FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.lesson_sub_chapters s JOIN public.lesson_chapters c ON s.chapter_id = c.id JOIN public.lesson_courses o ON c.course_id = o.id WHERE s.id = sub_chapter_id AND (o.is_public = true OR auth.uid() = o.creator_id))
);
CREATE POLICY "Manage own pages" ON public.lesson_pages FOR ALL USING (
    NOT EXISTS (SELECT 1 FROM public.lesson_sub_chapters WHERE id = sub_chapter_id) OR
    EXISTS (SELECT 1 FROM public.lesson_sub_chapters s JOIN public.lesson_chapters c ON s.chapter_id = c.id JOIN public.lesson_courses o ON c.course_id = o.id WHERE s.id = sub_chapter_id AND auth.uid() = o.creator_id)
);

-- Policies for blocks
CREATE POLICY "Viewable blocks" ON public.lesson_blocks FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.lesson_pages p JOIN public.lesson_sub_chapters s ON p.sub_chapter_id = s.id JOIN public.lesson_chapters c ON s.chapter_id = c.id JOIN public.lesson_courses o ON c.course_id = o.id WHERE p.id = page_id AND (o.is_public = true OR auth.uid() = o.creator_id))
);
CREATE POLICY "Manage own blocks" ON public.lesson_blocks FOR ALL USING (
    NOT EXISTS (SELECT 1 FROM public.lesson_pages WHERE id = page_id) OR
    EXISTS (SELECT 1 FROM public.lesson_pages p JOIN public.lesson_sub_chapters s ON p.sub_chapter_id = s.id JOIN public.lesson_chapters c ON s.chapter_id = c.id JOIN public.lesson_courses o ON c.course_id = o.id WHERE p.id = page_id AND auth.uid() = o.creator_id)
);

-- Enable Realtime Replication
ALTER PUBLICATION supabase_realtime ADD TABLE public.lesson_courses;
ALTER PUBLICATION supabase_realtime ADD TABLE public.lesson_chapters;
ALTER PUBLICATION supabase_realtime ADD TABLE public.lesson_sub_chapters;
ALTER PUBLICATION supabase_realtime ADD TABLE public.lesson_pages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.lesson_blocks;


-- =======================================================
-- 11. INTERACTIVE FLASHCARDS
-- =======================================================

-- Flashcard Decks Table
CREATE TABLE IF NOT EXISTS public.flashcard_decks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    creator_id UUID REFERENCES auth.users ON DELETE CASCADE DEFAULT auth.uid() NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    is_public BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Flashcards Table
CREATE TABLE IF NOT EXISTS public.flashcards (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    deck_id UUID REFERENCES public.flashcard_decks(id) ON DELETE CASCADE NOT NULL,
    front TEXT NOT NULL,
    back TEXT NOT NULL,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.flashcard_decks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcards ENABLE ROW LEVEL SECURITY;

-- Decks Policies
CREATE POLICY "Viewable decks" ON public.flashcard_decks FOR SELECT USING (is_public = true OR auth.uid() = creator_id);
CREATE POLICY "Insert own decks" ON public.flashcard_decks FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Update own decks" ON public.flashcard_decks FOR UPDATE USING (auth.uid() = creator_id);
CREATE POLICY "Delete own decks" ON public.flashcard_decks FOR DELETE USING (auth.uid() = creator_id);

-- Flashcards Policies
CREATE POLICY "Viewable cards" ON public.flashcards FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.flashcard_decks WHERE id = deck_id AND (is_public = true OR auth.uid() = creator_id))
);
CREATE POLICY "Manage own cards" ON public.flashcards FOR ALL USING (
    NOT EXISTS (SELECT 1 FROM public.flashcard_decks WHERE id = deck_id) OR
    EXISTS (SELECT 1 FROM public.flashcard_decks WHERE id = deck_id AND auth.uid() = creator_id)
);

-- Storage bucket for flashcards
INSERT INTO storage.buckets (id, name, public) VALUES ('flashcard_images', 'flashcard_images', true) ON CONFLICT (id) DO NOTHING;

-- Storage policies for flashcard_images
CREATE POLICY "Public Read Flashcard Images" ON storage.objects FOR SELECT USING (bucket_id = 'flashcard_images');
CREATE POLICY "Auth Insert Flashcard Images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'flashcard_images' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Update Flashcard Images" ON storage.objects FOR UPDATE USING (bucket_id = 'flashcard_images' AND auth.role() = 'authenticated');
CREATE POLICY "Auth Delete Flashcard Images" ON storage.objects FOR DELETE USING (bucket_id = 'flashcard_images' AND auth.role() = 'authenticated');

-- Enable Realtime Replication
ALTER PUBLICATION supabase_realtime ADD TABLE public.flashcard_decks;
ALTER PUBLICATION supabase_realtime ADD TABLE public.flashcards;


-- =======================================================
-- 12. DATABASE OPTIMIZATION INDEXES
-- =======================================================

-- Lesson schema indexes
CREATE INDEX IF NOT EXISTS idx_lesson_chapters_course_id ON public.lesson_chapters(course_id);
CREATE INDEX IF NOT EXISTS idx_lesson_sub_chapters_chapter_id ON public.lesson_sub_chapters(chapter_id);
CREATE INDEX IF NOT EXISTS idx_lesson_pages_sub_chapter_id ON public.lesson_pages(sub_chapter_id);
CREATE INDEX IF NOT EXISTS idx_lesson_blocks_page_id ON public.lesson_blocks(page_id);
CREATE INDEX IF NOT EXISTS idx_lesson_courses_creator_id ON public.lesson_courses(creator_id);

-- Quiz schema indexes
CREATE INDEX IF NOT EXISTS idx_quizzes_creator_id ON public.quizzes(creator_id);
CREATE INDEX IF NOT EXISTS idx_questions_quiz_id ON public.questions(quiz_id);
CREATE INDEX IF NOT EXISTS idx_options_question_id ON public.options(question_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_id ON public.quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_quiz_id ON public.quiz_attempts(quiz_id);

-- Friendship & Discussion indexes
CREATE INDEX IF NOT EXISTS idx_friendships_sender_id ON public.friendships(sender_id);
CREATE INDEX IF NOT EXISTS idx_friendships_receiver_id ON public.friendships(receiver_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_discussion_topics_author_id ON public.discussion_topics(author_id);
CREATE INDEX IF NOT EXISTS idx_discussion_replies_topic_id ON public.discussion_replies(topic_id);
CREATE INDEX IF NOT EXISTS idx_discussion_replies_author_id ON public.discussion_replies(author_id);
CREATE INDEX IF NOT EXISTS idx_discussion_replies_parent_id ON public.discussion_replies(parent_id);

-- Flashcards indexes
CREATE INDEX IF NOT EXISTS idx_flashcard_decks_creator_id ON public.flashcard_decks(creator_id);
CREATE INDEX IF NOT EXISTS idx_flashcards_deck_id ON public.flashcards(deck_id);


-- =======================================================
-- 13. WEEKLY LEAGUE LEADERBOARD SYSTEM
-- =======================================================

-- Add weekly_xp and league columns to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS weekly_xp INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS league TEXT DEFAULT 'Stargazer';

-- Create league configurations table
CREATE TABLE IF NOT EXISTS public.league_configs (
    league TEXT PRIMARY KEY,
    rank_order INTEGER NOT NULL,
    min_weekly_xp INTEGER NOT NULL,
    promotion_pct DOUBLE PRECISION NOT NULL,
    demotion_pct DOUBLE PRECISION NOT NULL
);

-- Seed default league configurations (Top 20% promoted, Bottom 10% demoted)
INSERT INTO public.league_configs (league, rank_order, min_weekly_xp, promotion_pct, demotion_pct) VALUES
('Stargazer', 1, 10, 0.20, 0.10),
('Explorer', 2, 20, 0.20, 0.10),
('Voyager', 3, 30, 0.20, 0.10),
('Stellar Scholar', 4, 40, 0.20, 0.10),
('Galactic Sage', 5, 50, 0.20, 0.10),
('Cosmic Legend', 6, 60, 0.20, 0.10)
ON CONFLICT (league) DO NOTHING;

-- Index on league column to optimize leaderboard grouping queries
CREATE INDEX IF NOT EXISTS idx_profiles_league_weekly_xp ON public.profiles(league, weekly_xp DESC);

-- RPC Function for Weekly Reset Promotion/Demotion logic
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
BEGIN
    -- Create temporary table to store updates
    CREATE TEMP TABLE temp_league_updates (
        user_id UUID PRIMARY KEY,
        new_league TEXT
    ) ON COMMIT DROP;

    -- Iterate through leagues sorted by order
    FOR league_rec IN 
        SELECT league, rank_order, min_weekly_xp, promotion_pct, demotion_pct
        FROM public.league_configs
        ORDER BY rank_order ASC
    LOOP
        -- Count users currently in this league
        SELECT COUNT(*) INTO total_users 
        FROM public.profiles 
        WHERE league = league_rec.league;

        IF total_users > 0 THEN
            promo_pct := league_rec.promotion_pct;
            demo_pct := league_rec.demotion_pct;
            min_xp := league_rec.min_weekly_xp;

            -- Ceiling rounding ensures that even in small lists, at least 1 person can be promoted/demoted
            promo_count := CEIL(total_users * promo_pct);
            demo_count := CEIL(total_users * demo_pct);

            user_rank := 0;
            -- Fetch all users in this league sorted by weekly_xp desc
            FOR user_rec IN 
                SELECT id, weekly_xp 
                FROM public.profiles 
                WHERE league = league_rec.league
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

                -- If the league has changed, save to updates table
                IF v_new_league <> league_rec.league THEN
                    INSERT INTO temp_league_updates (user_id, new_league)
                    VALUES (user_rec.id, v_new_league);
                END IF;
            END LOOP;
        END IF;
    END LOOP;

    -- Apply promotions/demotions to profiles table using a safe loop to bypass Safe Update constraints
    FOR user_rec IN SELECT user_id, new_league FROM temp_league_updates LOOP
        UPDATE public.profiles
        SET league = user_rec.new_league
        WHERE id = user_rec.user_id;
    END LOOP;

    -- Reset weekly XP for all users back to 0
    UPDATE public.profiles
    SET weekly_xp = 0
    WHERE id IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =======================================================
-- 14. LEADERBOARD SANDBOX TESTING RPC HELPERS (Bypass RLS)
-- =======================================================

-- Adjust any user's weekly XP
CREATE OR REPLACE FUNCTION public.test_adjust_user_xp(target_user_id UUID, xp_change INTEGER)
RETURNS void AS $$
BEGIN
    UPDATE public.profiles
    SET weekly_xp = GREATEST(0, LEAST(1000, weekly_xp + xp_change))
    WHERE id = target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Generate 5 mock profiles in target league
CREATE OR REPLACE FUNCTION public.test_add_dummy_users(target_league TEXT)
RETURNS void AS $$
DECLARE
    dummy_id UUID;
    i INTEGER;
BEGIN
    FOR i IN 1..5 LOOP
        dummy_id := ('00000000-0000-0000-0000-00000000000' || i)::uuid;
        
        -- Delete profile and auth user if exists
        DELETE FROM public.profiles WHERE id = dummy_id;
        DELETE FROM auth.users WHERE id = dummy_id;
        
        -- Insert into auth.users first to satisfy foreign key constraint
        INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
        VALUES (dummy_id, 'dummy' || i || '@quiztime.com', jsonb_build_object('name', 'Test User ' || i), 'authenticated', 'authenticated');
        
        -- Update the created profile (which was automatically inserted by handle_new_user trigger)
        UPDATE public.profiles
        SET weekly_xp = i * 15,
            xp = i * 100,
            league = target_league
        WHERE id = dummy_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Delete all test mock profiles
CREATE OR REPLACE FUNCTION public.test_clear_dummy_users()
RETURNS void AS $$
BEGIN
    -- Deleting from auth.users will automatically cascade delete from public.profiles
    DELETE FROM auth.users WHERE email LIKE 'dummy%@quiztime.com';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


