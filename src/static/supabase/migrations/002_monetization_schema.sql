-- ============================================
-- SKILLSWAP PLATFORM - CRITICAL MONETIZATION SCHEMA
-- Additions: Platform fees, payouts, subscriptions, disputes, premium features
-- ============================================

-- ============================================
-- PLATFORM CONFIGURATION TABLE
-- ============================================
CREATE TABLE platform_config (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    platform_fee_percent DECIMAL(4,2) DEFAULT 20.00, -- 20% platform fee
    min_session_credits INTEGER DEFAULT 1,
    max_session_credits INTEGER DEFAULT 100,
    credit_purchase_bonus_percent INTEGER DEFAULT 0,
    teacher_verification_cost_credits INTEGER DEFAULT 50,
    featured_listing_cost_credits INTEGER DEFAULT 10,
    featured_listing_duration_hours INTEGER DEFAULT 168, -- 7 days
    dispute_window_hours INTEGER DEFAULT 48,
    min_withdrawal_credits INTEGER DEFAULT 100,
    credit_to_usd_rate DECIMAL(10,4) DEFAULT 0.50, -- 1 credit = $0.50
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO platform_config DEFAULT VALUES;

COMMENT ON TABLE platform_config IS 'Singleton table for platform-wide settings';

-- ============================================
-- PAYOUTS TABLE (for teachers to cash out)
-- ============================================
CREATE TYPE payout_status AS ENUM ('pending', 'processing', 'completed', 'rejected');
CREATE TYPE payout_method AS ENUM ('paypal', 'bank_transfer', 'crypto', 'stripe');

CREATE TABLE payouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    credits_amount INTEGER NOT NULL CHECK (credits_amount > 0),
    usd_amount DECIMAL(10,2) NOT NULL,
    platform_fee_deducted DECIMAL(10,2) NOT NULL,
    net_amount DECIMAL(10,2) NOT NULL,
    method payout_method NOT NULL,
    payout_email TEXT,
    bank_account_last4 TEXT,
    crypto_address TEXT,
    status payout_status DEFAULT 'pending',
    processed_at TIMESTAMPTZ,
    processor_reference TEXT,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE payouts IS 'Teacher withdrawal requests - platform takes fee';

-- ============================================
-- SUBSCRIPTION PLANS
-- ============================================
CREATE TABLE subscription_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    price_monthly_usd DECIMAL(10,2) NOT NULL,
    price_yearly_usd DECIMAL(10,2),
    features JSONB DEFAULT '[]',
    credits_included_monthly INTEGER DEFAULT 0,
    featured_listings_included INTEGER DEFAULT 0,
    verification_included BOOLEAN DEFAULT FALSE,
    priority_support BOOLEAN DEFAULT FALSE,
    analytics_access BOOLEAN DEFAULT FALSE,
    commission_discount_percent INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    stripe_price_id_monthly TEXT,
    stripe_price_id_yearly TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO subscription_plans (name, description, price_monthly_usd, price_yearly_usd, features, credits_included_monthly, commission_discount_percent) VALUES
('Free', 'Basic skill exchange', 0.00, 0.00, '["Basic profile","Standard search","Community support"]', 0, 0),
('Pro', 'Enhanced learning experience', 9.99, 99.99, '["Featured profile badge","Priority matching","Advanced analytics","5 featured listings/month"]', 20, 10),
('Teacher Pro', 'For active teachers', 19.99, 199.99, '["Reduced platform fees","Verified badge","Unlimited featured listings","Priority support","Custom booking page"]', 50, 25),
('Enterprise', 'For organizations', 49.99, 499.99, '["Team management","Custom branding","API access","Dedicated account manager","White-label options"]', 200, 50);

-- ============================================
-- USER SUBSCRIPTIONS
-- ============================================
CREATE TABLE user_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id),
    stripe_subscription_id TEXT UNIQUE,
    stripe_customer_id TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'past_due', 'trialing', 'paused')),
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    trial_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id, plan_id)
);

-- ============================================
-- DISPUTES TABLE
-- ============================================
CREATE TYPE dispute_status AS ENUM ('open', 'under_review', 'resolved_buyer', 'resolved_seller', 'rejected');

CREATE TABLE disputes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    opened_by UUID NOT NULL REFERENCES profiles(id),
    respondent_id UUID NOT NULL REFERENCES profiles(id),
    reason TEXT NOT NULL,
    description TEXT,
    evidence JSONB DEFAULT '[]',
    status dispute_status DEFAULT 'open',
    resolution_notes TEXT,
    credits_refunded INTEGER DEFAULT 0,
    resolved_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,

    CONSTRAINT different_dispute_parties CHECK (opened_by != respondent_id)
);

-- ============================================
-- FEATURED LISTINGS
-- ============================================
CREATE TABLE featured_listings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    skill_name TEXT NOT NULL,
    start_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_at TIMESTAMPTZ NOT NULL,
    credits_paid INTEGER NOT NULL,
    impressions INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    bookings_generated INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- CREDIT PACKAGES (for purchase)
-- ============================================
CREATE TABLE credit_packages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    credits INTEGER NOT NULL CHECK (credits > 0),
    price_usd DECIMAL(10,2) NOT NULL,
    bonus_credits INTEGER DEFAULT 0,
    description TEXT,
    stripe_price_id TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO credit_packages (name, credits, price_usd, bonus_credits, description) VALUES
('Starter', 20, 9.99, 2, 'Perfect for trying out'),
('Popular', 50, 19.99, 10, 'Best value for learners'),
('Power', 100, 34.99, 25, 'For serious learners'),
('Pro', 250, 79.99, 75, 'Maximum value pack');

-- ============================================
-- STRIPE WEBHOOK EVENTS LOG
-- ============================================
CREATE TABLE stripe_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stripe_event_id TEXT UNIQUE NOT NULL,
    event_type TEXT NOT NULL,
    event_data JSONB NOT NULL,
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- AUDIT LOG (for admin transparency)
-- ============================================
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name TEXT NOT NULL,
    record_id UUID,
    action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    performed_by UUID REFERENCES profiles(id),
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ADMIN USERS (separate from regular profiles)
-- ============================================
CREATE TABLE admin_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'moderator' CHECK (role IN ('super_admin', 'admin', 'moderator', 'support')),
    permissions JSONB DEFAULT '[]',
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- PLATFORM REVENUE SUMMARY (materialized view)
-- ============================================
CREATE MATERIALIZED VIEW platform_revenue_summary AS
SELECT 
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) FILTER (WHERE type = 'purchase') as credit_purchases_count,
    SUM(ABS(amount)) FILTER (WHERE type = 'purchase') as credits_purchased,
    COUNT(*) FILTER (WHERE type = 'earn') as sessions_completed_count,
    SUM(ABS(amount)) FILTER (WHERE type = 'earn') as credits_earned_by_teachers,
    COUNT(*) FILTER (WHERE type = 'spend') as credits_spent_count,
    SUM(ABS(amount)) FILTER (WHERE type = 'spend') as credits_spent_by_learners
FROM credit_transactions
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- ============================================
-- UPDATED TRIGGERS WITH PLATFORM FEE
-- ============================================

-- Drop old trigger and recreate with platform fee
DROP TRIGGER IF EXISTS trg_update_session_counts ON sessions;
DROP FUNCTION IF EXISTS update_session_counts();

CREATE OR REPLACE FUNCTION update_session_counts_with_fee()
RETURNS TRIGGER AS $$
DECLARE
    fee_percent DECIMAL(4,2);
    teacher_earns INTEGER;
    platform_fee INTEGER;
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Get platform fee
        SELECT platform_fee_percent INTO fee_percent FROM platform_config WHERE id = 1;
        platform_fee := CEIL(NEW.credits_cost * fee_percent / 100);
        teacher_earns := NEW.credits_cost - platform_fee;

        -- Update teacher stats (earns after fee)
        UPDATE profiles
        SET 
            total_sessions_taught = total_sessions_taught + 1,
            credits = credits + teacher_earns,
            updated_at = NOW()
        WHERE id = NEW.teacher_id;

        -- Update learner stats
        UPDATE profiles
        SET 
            total_sessions_learned = total_sessions_learned + 1,
            credits = credits - NEW.credits_cost,
            updated_at = NOW()
        WHERE id = NEW.learner_id;

        -- Teacher earns (after platform fee)
        INSERT INTO credit_transactions (user_id, amount, type, description, session_id, balance_after)
        SELECT 
            NEW.teacher_id,
            teacher_earns,
            'earn',
            'Earned ' || teacher_earns || ' credits from teaching (after ' || fee_percent || '% platform fee)',
            NEW.id,
            credits + teacher_earns
        FROM profiles WHERE id = NEW.teacher_id;

        -- Platform fee transaction (negative to teacher, tracked separately)
        INSERT INTO credit_transactions (user_id, amount, type, description, session_id, balance_after)
        SELECT 
            NEW.teacher_id,
            -platform_fee,
            'penalty',
            'Platform fee (' || fee_percent || '%) for session #' || substring(NEW.id::text, 1, 8),
            NEW.id,
            credits + teacher_earns - platform_fee
        FROM profiles WHERE id = NEW.teacher_id;

        -- Learner spends
        INSERT INTO credit_transactions (user_id, amount, type, description, session_id, balance_after)
        SELECT 
            NEW.learner_id,
            -NEW.credits_cost,
            'spend',
            'Spent ' || NEW.credits_cost || ' credits on learning session',
            NEW.id,
            credits - NEW.credits_cost
        FROM profiles WHERE id = NEW.learner_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_session_counts_with_fee
AFTER UPDATE ON sessions
FOR EACH ROW
EXECUTE FUNCTION update_session_counts_with_fee();

-- ============================================
-- AUDIT LOG TRIGGER
-- ============================================
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_data, performed_by)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', row_to_json(OLD), auth.uid());
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_data, new_data, performed_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', row_to_json(OLD), row_to_json(NEW), auth.uid());
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, action, new_data, performed_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', row_to_json(NEW), auth.uid());
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit to critical tables
CREATE TRIGGER audit_sessions AFTER INSERT OR UPDATE OR DELETE ON sessions
FOR EACH ROW EXECUTE FUNCTION audit_trigger();
CREATE TRIGGER audit_profiles AFTER INSERT OR UPDATE OR DELETE ON profiles
FOR EACH ROW EXECUTE FUNCTION audit_trigger();
CREATE TRIGGER audit_credit_transactions AFTER INSERT OR UPDATE OR DELETE ON credit_transactions
FOR EACH ROW EXECUTE FUNCTION audit_trigger();
CREATE TRIGGER audit_payouts AFTER INSERT OR UPDATE OR DELETE ON payouts
FOR EACH ROW EXECUTE FUNCTION audit_trigger();

-- ============================================
-- RLS POLICIES FOR NEW TABLES
-- ============================================

ALTER TABLE payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE featured_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE stripe_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;

-- Payouts: readable by owner, insertable by owner
CREATE POLICY "Payouts viewable by owner" ON payouts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Payouts insertable by owner" ON payouts FOR INSERT WITH CHECK (auth.uid() = user_id);

-- User subscriptions: readable by owner
CREATE POLICY "Subscriptions viewable by owner" ON user_subscriptions FOR SELECT USING (auth.uid() = user_id);

-- Disputes: readable by participants, insertable by session participants
CREATE POLICY "Disputes viewable by participants" ON disputes FOR SELECT USING (
    auth.uid() = opened_by OR auth.uid() = respondent_id
);
CREATE POLICY "Disputes insertable by session participants" ON disputes FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM sessions 
        WHERE id = session_id 
        AND (teacher_id = auth.uid() OR learner_id = auth.uid())
    )
);

-- Featured listings: readable by all, insertable by owner
CREATE POLICY "Featured listings viewable by all" ON featured_listings FOR SELECT USING (TRUE);
CREATE POLICY "Featured listings insertable by owner" ON featured_listings FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Credit packages: readable by all
CREATE POLICY "Credit packages viewable by all" ON credit_packages FOR SELECT USING (is_active = TRUE);

-- Admin tables: only admins
CREATE POLICY "Admin only" ON admin_users FOR ALL USING (
    EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid())
);
CREATE POLICY "Audit log admin only" ON audit_log FOR SELECT USING (
    EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid())
);
CREATE POLICY "Stripe events admin only" ON stripe_events FOR ALL USING (
    EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid())
);

-- Platform config: readable by all, updatable by admin only
CREATE POLICY "Platform config readable by all" ON platform_config FOR SELECT USING (TRUE);
CREATE POLICY "Platform config admin update" ON platform_config FOR UPDATE USING (
    EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid())
);

-- ============================================
-- FUNCTIONS FOR ADMIN DASHBOARD
-- ============================================

-- Get platform stats
CREATE OR REPLACE FUNCTION get_platform_stats()
RETURNS TABLE (
    total_users BIGINT,
    active_users BIGINT,
    total_sessions BIGINT,
    completed_sessions BIGINT,
    total_credits_in_circulation BIGINT,
    total_credits_purchased BIGINT,
    total_platform_fees BIGINT,
    avg_session_rating DECIMAL,
    pending_payouts BIGINT,
    open_disputes BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM profiles),
        (SELECT COUNT(*) FROM profiles WHERE is_active = TRUE),
        (SELECT COUNT(*) FROM sessions),
        (SELECT COUNT(*) FROM sessions WHERE status = 'completed'),
        (SELECT COALESCE(SUM(credits), 0) FROM profiles),
        (SELECT COALESCE(SUM(ABS(amount)), 0) FROM credit_transactions WHERE type = 'purchase'),
        (SELECT COALESCE(SUM(ABS(amount)), 0) FROM credit_transactions WHERE type = 'penalty'),
        (SELECT COALESCE(AVG(rating), 0) FROM reviews),
        (SELECT COUNT(*) FROM payouts WHERE status = 'pending'),
        (SELECT COUNT(*) FROM disputes WHERE status = 'open');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get top teachers
CREATE OR REPLACE FUNCTION get_top_teachers(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    display_name TEXT,
    total_earned BIGINT,
    sessions_taught BIGINT,
    avg_rating DECIMAL,
    skills_teaching TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.username,
        p.display_name,
        COALESCE(SUM(ABS(ct.amount)), 0) FILTER (WHERE ct.type = 'earn') as total_earned,
        p.total_sessions_taught,
        p.rating_average,
        p.skills_teaching
    FROM profiles p
    LEFT JOIN credit_transactions ct ON p.id = ct.user_id
    WHERE p.is_active = TRUE
    GROUP BY p.id
    ORDER BY total_earned DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Refresh materialized view function
CREATE OR REPLACE FUNCTION refresh_revenue_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW platform_revenue_summary;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
