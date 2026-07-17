export interface Profile {
    id: string;
    username: string;
    display_name: string | null;
    avatar_url: string | null;
    bio: string | null;
    location: string | null;
    skills_teaching: string[];
    skills_learning: string[];
    credits: number;
    rating_average: number;
    total_sessions_taught: number;
    total_sessions_learned: number;
    total_reviews_received: number;
    is_verified: boolean;
    is_active: boolean;
    timezone: string;
    created_at: string;
}

export interface Session {
    id: string;
    teacher_id: string;
    learner_id: string;
    skill_taught: string;
    skill_learned: string;
    status: 'pending' | 'accepted' | 'scheduled' | 'in_progress' | 'completed' | 'cancelled' | 'disputed';
    format: 'video' | 'chat' | 'in_person';
    scheduled_at: string | null;
    duration_minutes: number;
    credits_cost: number;
    teacher_notes: string | null;
    learner_notes: string | null;
    meeting_link: string | null;
    created_at: string;
    teacher?: Profile;
    learner?: Profile;
}

export interface Review {
    id: string;
    session_id: string;
    reviewer_id: string;
    reviewee_id: string;
    rating: number;
    comment: string | null;
    is_teacher_review: boolean;
    helpful_count: number;
    created_at: string;
    reviewer?: Profile;
}

export interface CreditTransaction {
    id: string;
    user_id: string;
    amount: number;
    type: 'earn' | 'spend' | 'purchase' | 'bonus' | 'refund' | 'penalty';
    description: string | null;
    session_id: string | null;
    balance_after: number;
    created_at: string;
}

export interface Message {
    id: string;
    session_id: string;
    sender_id: string;
    content: string;
    is_read: boolean;
    created_at: string;
    sender?: Profile;
}

export interface Notification {
    id: string;
    user_id: string;
    type: string;
    title: string;
    message: string;
    data: Record<string, any>;
    is_read: boolean;
    created_at: string;
}

export interface SkillCategory {
    id: string;
    name: string;
    description: string | null;
    icon: string | null;
    color: string | null;
    parent_id: string | null;
    sort_order: number;
    is_active: boolean;
}
