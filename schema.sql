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

-- 2. CREATE TABLES

-- Profiles Table (Extension of Auth.Users)
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    email TEXT,
    name TEXT,
    avatar_url TEXT,
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
    INSERT INTO public.profiles (id, email, name)
    VALUES (new.id, new.email, new.raw_user_meta_data->>'name');
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

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
