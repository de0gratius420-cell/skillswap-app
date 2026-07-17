-- ============================================
-- SKILLSWAP PLATFORM - COMPLETE DATABASE SCHEMA
-- A peer-to-peer skill exchange & tutoring platform
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For GIN trigram indexes

-- ============================================
-- PROFILES TABLE (extends auth.users)
-- ============================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    location TEXT,
    skills_teaching TEXT[] DEFAULT '{}',
    skills_learning TEXT[] DEFAULT '{}',
    credits INTEGER DEFAULT 10, -- Starting credits for new users
    rating_average DECIMAL(2,1) DEFAULT 5.0 CHECK (rating_average >= 0 AND rating_average <= 5),
    total_sessions_taught INTEGER DEFAULT 0,
    total_sessions_learned INTEGER DEFAULT 0,
    total_reviews_received INTEGER DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    timezone TEXT DEFAULT 'UTC',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE profiles IS 'User profiles extending Supabase auth';
COMMENT ON COLUMN profiles.credits IS 'Platform currency: earn by teaching, spend by learning';
COMMENT ON COLUMN profiles.rating_average IS 'Average rating from 1-5 stars';

-- ============================================
-- SESSIONS TABLE
-- ============================================
CREATE TYPE session_status AS ENUM ('pending', 'accepted', 'scheduled', 'in_progress', 'completed', 'cancelled', 'disputed');
CREATE TYPE session_format AS ENUM ('video', 'chat', 'in_person');

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    teacher_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    learner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    skill_taught TEXT NOT NULL,
    skill_learned TEXT NOT NULL,
    status session_status DEFAULT 'pending',
    format session_format DEFAULT 'video',
    scheduled_at TIMESTAMPTZ,
    duration_minutes INTEGER DEFAULT 60,
    credits_cost INTEGER DEFAULT 2,
    teacher_notes TEXT,
    learner_notes TEXT,
    meeting_link TEXT,
    location_address TEXT,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT different_participants CHECK (teacher_id != learner_id),
    CONSTRAINT positive_duration CHECK (duration_minutes > 0),
    CONSTRAINT positive_credits CHECK (credits_cost > 0)
);

COMMENT ON TABLE sessions IS 'Learning sessions between teachers and learners';

-- ============================================
-- REVIEWS TABLE
-- ============================================
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reviewee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    is_teacher_review BOOLEAN DEFAULT FALSE, -- TRUE if teacher reviewed learner, FALSE if learner reviewed teacher
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT one_review_per_session_per_user UNIQUE (session_id, reviewer_id),
    CONSTRAINT no_self_review CHECK (reviewer_id != reviewee_id)
);

COMMENT ON TABLE reviews IS 'Session reviews and ratings';

-- ============================================
-- CREDIT TRANSACTIONS TABLE
-- ============================================
CREATE TYPE transaction_type AS ENUM ('earn', 'spend', 'purchase', 'bonus', 'refund', 'penalty');

CREATE TABLE credit_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    type transaction_type NOT NULL,
    description TEXT,
    session_id UUID REFERENCES sessions(id),
    balance_after INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE credit_transactions IS 'Audit log of all credit movements';

-- ============================================
-- MESSAGES TABLE (for session communication)
-- ============================================
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE messages IS 'Chat messages between session participants';

-- ============================================
-- SKILL CATEGORIES TABLE (for discovery)
-- ============================================
CREATE TABLE skill_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    icon TEXT,
    color TEXT,
    parent_id UUID REFERENCES skill_categories(id),
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- USER SKILL PREFERENCES (for matching)
-- ============================================
CREATE TABLE user_skill_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    skill_name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('teach', 'learn')),
    proficiency_level INTEGER CHECK (proficiency_level BETWEEN 1 AND 5),
    hourly_rate_credits INTEGER DEFAULT 2,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, skill_name, type)
);

-- ============================================
-- NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================

-- GIN indexes for array/text search (fast skill matching)
CREATE INDEX idx_profiles_skills_teaching_gin ON profiles USING GIN (skills_teaching);
CREATE INDEX idx_profiles_skills_learning_gin ON profiles USING GIN (skills_learning);

-- Composite indexes for common queries
CREATE INDEX idx_sessions_teacher_learner_status ON sessions(teacher_id, learner_id, status);
CREATE INDEX idx_sessions_scheduled_at ON sessions(scheduled_at);
CREATE INDEX idx_sessions_status ON sessions(status) WHERE status IN ('pending', 'accepted', 'scheduled');
CREATE INDEX idx_reviews_reviewee ON reviews(reviewee_id);
CREATE INDEX idx_reviews_session ON reviews(session_id);
CREATE INDEX idx_credit_transactions_user ON credit_transactions(user_id, created_at DESC);
CREATE INDEX idx_messages_session ON messages(session_id, created_at DESC);
CREATE INDEX idx_messages_unread ON messages(session_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_user_skill_prefs_user ON user_skill_preferences(user_id, type);

-- Full-text search indexes
CREATE INDEX idx_profiles_username_trgm ON profiles USING GIN (username gin_trgm_ops);
CREATE INDEX idx_profiles_bio_trgm ON profiles USING GIN (bio gin_trgm_ops);

-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger 1: Auto-update profiles.rating_average when a review is inserted
CREATE OR REPLACE FUNCTION update_profile_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE profiles
    SET 
        rating_average = (
            SELECT ROUND(AVG(rating)::numeric, 1)
            FROM reviews
            WHERE reviewee_id = NEW.reviewee_id
        ),
        total_reviews_received = (
            SELECT COUNT(*)::INTEGER
            FROM reviews
            WHERE reviewee_id = NEW.reviewee_id
        ),
        updated_at = NOW()
    WHERE id = NEW.reviewee_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_profile_rating
AFTER INSERT ON reviews
FOR EACH ROW
EXECUTE FUNCTION update_profile_rating();

-- Trigger 2: Auto-update profiles.total_sessions_taught/learned when session completes
CREATE OR REPLACE FUNCTION update_session_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Update teacher stats
        UPDATE profiles
        SET 
            total_sessions_taught = total_sessions_taught + 1,
            credits = credits + NEW.credits_cost,
            updated_at = NOW()
        WHERE id = NEW.teacher_id;

        -- Update learner stats
        UPDATE profiles
        SET 
            total_sessions_learned = total_sessions_learned + 1,
            credits = credits - NEW.credits_cost,
            updated_at = NOW()
        WHERE id = NEW.learner_id;

        -- Create credit transaction for teacher (earn)
        INSERT INTO credit_transactions (user_id, amount, type, description, session_id, balance_after)
        SELECT 
            NEW.teacher_id,
            NEW.credits_cost,
            'earn',
            'Earned credits from teaching session',
            NEW.id,
            credits + NEW.credits_cost
        FROM profiles WHERE id = NEW.teacher_id;

        -- Create credit transaction for learner (spend)
        INSERT INTO credit_transactions (user_id, amount, type, description, session_id, balance_after)
        SELECT 
            NEW.learner_id,
            -NEW.credits_cost,
            'spend',
            'Spent credits on learning session',
            NEW.id,
            credits - NEW.credits_cost
        FROM profiles WHERE id = NEW.learner_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_session_counts
AFTER UPDATE ON sessions
FOR EACH ROW
EXECUTE FUNCTION update_session_counts();

-- Trigger 3: Auto-update profiles.credits on credit_transactions insert (backup/audit)
CREATE OR REPLACE FUNCTION log_credit_transaction()
RETURNS TRIGGER AS $$
BEGIN
    -- Ensure balance matches
    UPDATE profiles
    SET credits = NEW.balance_after,
        updated_at = NOW()
    WHERE id = NEW.user_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_credit_transaction
AFTER INSERT ON credit_transactions
FOR EACH ROW
EXECUTE FUNCTION log_credit_transaction();

-- Trigger 4: Auto-create profile on auth signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, username, display_name, credits)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substr(NEW.id::text, 1, 8)),
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        10 -- Welcome bonus credits
    );

    -- Welcome bonus transaction
    INSERT INTO credit_transactions (user_id, amount, type, description, balance_after)
    VALUES (NEW.id, 10, 'bonus', 'Welcome bonus credits!', 10);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_handle_new_user
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION handle_new_user();

-- Trigger 5: Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_sessions_updated_at
BEFORE UPDATE ON sessions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_skill_preferences ENABLE ROW LEVEL SECURITY;

-- Profiles: readable by all, writable only by owner
CREATE POLICY "Profiles are viewable by everyone" 
ON profiles FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Users can update own profile" 
ON profiles FOR UPDATE USING (auth.uid() = id);

-- Sessions: readable/writable only by participants
CREATE POLICY "Sessions viewable by participants" 
ON sessions FOR SELECT USING (
    auth.uid() = teacher_id OR auth.uid() = learner_id
);

CREATE POLICY "Sessions insertable by authenticated" 
ON sessions FOR INSERT WITH CHECK (auth.uid() = learner_id);

CREATE POLICY "Sessions updatable by participants" 
ON sessions FOR UPDATE USING (
    auth.uid() = teacher_id OR auth.uid() = learner_id
);

-- Reviews: readable by all, writable only by session participants
CREATE POLICY "Reviews viewable by everyone" 
ON reviews FOR SELECT USING (TRUE);

CREATE POLICY "Reviews insertable by session participants" 
ON reviews FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM sessions 
        WHERE id = session_id 
        AND (teacher_id = auth.uid() OR learner_id = auth.uid())
        AND status = 'completed'
    )
);

-- Credit transactions: readable only by owning user
CREATE POLICY "Credit transactions viewable by owner" 
ON credit_transactions FOR SELECT USING (auth.uid() = user_id);

-- Messages: readable/writable only by session participants
CREATE POLICY "Messages viewable by session participants" 
ON messages FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM sessions 
        WHERE id = session_id 
        AND (teacher_id = auth.uid() OR learner_id = auth.uid())
    )
);

CREATE POLICY "Messages insertable by session participants" 
ON messages FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM sessions 
        WHERE id = session_id 
        AND (teacher_id = auth.uid() OR learner_id = auth.uid())
    )
);

-- Notifications: readable only by owning user
CREATE POLICY "Notifications viewable by owner" 
ON notifications FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Notifications updatable by owner" 
ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- User skill preferences: readable by all, writable by owner
CREATE POLICY "Skill preferences viewable by everyone" 
ON user_skill_preferences FOR SELECT USING (TRUE);

CREATE POLICY "Skill preferences manageable by owner" 
ON user_skill_preferences FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- SEED DATA
-- ============================================

INSERT INTO skill_categories (name, description, icon, color, sort_order) VALUES
('Programming', 'Software development and coding', 'code', '#3B82F6', 1),
('Languages', 'Spoken languages and communication', 'languages', '#10B981', 2),
('Music', 'Instruments, theory, and production', 'music', '#8B5CF6', 3),
('Design', 'Graphic, UI/UX, and visual design', 'design', '#F59E0B', 4),
('Business', 'Entrepreneurship, marketing, finance', 'briefcase', '#EF4444', 5),
('Academics', 'Math, science, humanities', 'book', '#6366F1', 6),
('Fitness', 'Exercise, nutrition, wellness', 'heart', '#EC4899', 7),
('Cooking', 'Culinary arts and baking', 'utensils', '#D97706', 8);

-- Subcategories
INSERT INTO skill_categories (name, description, icon, color, parent_id, sort_order) VALUES
('JavaScript', 'Web programming language', 'js', '#F7DF1E', (SELECT id FROM skill_categories WHERE name = 'Programming'), 1),
('Python', 'General-purpose programming', 'python', '#3776AB', (SELECT id FROM skill_categories WHERE name = 'Programming'), 2),
('Spanish', 'Spanish language learning', 'es', '#F59E0B', (SELECT id FROM skill_categories WHERE name = 'Languages'), 1),
('Guitar', 'Acoustic and electric guitar', 'guitar', '#8B5CF6', (SELECT id FROM skill_categories WHERE name = 'Music'), 1),
('Photoshop', 'Image editing and manipulation', 'ps', '#31A8FF', (SELECT id FROM skill_categories WHERE name = 'Design'), 1);

-- ============================================
-- VIEWS FOR CONVENIENCE
-- ============================================

CREATE VIEW session_details AS
SELECT 
    s.*,
    t.username as teacher_username,
    t.display_name as teacher_name,
    t.avatar_url as teacher_avatar,
    l.username as learner_username,
    l.display_name as learner_name,
    l.avatar_url as learner_avatar
FROM sessions s
JOIN profiles t ON s.teacher_id = t.id
JOIN profiles l ON s.learner_id = l.id;

CREATE VIEW user_stats AS
SELECT 
    p.id,
    p.username,
    p.display_name,
    p.rating_average,
    p.total_sessions_taught,
    p.total_sessions_learned,
    p.credits,
    p.skills_teaching,
    p.skills_learning,
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'completed') as completed_sessions,
    COUNT(DISTINCT r.id) as total_reviews
FROM profiles p
LEFT JOIN sessions s ON (p.id = s.teacher_id OR p.id = s.learner_id)
LEFT JOIN reviews r ON p.id = r.reviewee_id
WHERE p.is_active = TRUE
GROUP BY p.id;
