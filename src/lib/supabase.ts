import { createClient } from '@supabase/supabase-js'
import type { Database } from './database.types'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
    auth: {
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true
    }
})

// Auth helpers
export const getCurrentUser = async () => {
    const { data: { user } } = await supabase.auth.getUser()
    return user
}

export const getCurrentProfile = async () => {
    const user = await getCurrentUser()
    if (!user) return null

    const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single()

    if (error) throw error
    return data
}

// Session helpers
export const createSession = async (sessionData: {
    teacher_id: string;
    skill_taught: string;
    skill_learned: string;
    credits_cost: number;
    format?: string;
    scheduled_at?: string;
    duration_minutes?: number;
    learner_notes?: string;
}) => {
    const user = await getCurrentUser()
    if (!user) throw new Error('Not authenticated')

    const { data, error } = await supabase
        .from('sessions')
        .insert({
            ...sessionData,
            learner_id: user.id,
            status: 'pending'
        })
        .select()
        .single()

    if (error) throw error
    return data
}

export const getMySessions = async (status?: string) => {
    const user = await getCurrentUser()
    if (!user) throw new Error('Not authenticated')

    let query = supabase
        .from('sessions')
        .select(`
            *,
            teacher:profiles!sessions_teacher_id_fkey(*),
            learner:profiles!sessions_learner_id_fkey(*)
        `)
        .or(`teacher_id.eq.${user.id},learner_id.eq.${user.id}`)
        .order('created_at', { ascending: false })

    if (status) {
        query = query.eq('status', status)
    }

    const { data, error } = await query
    if (error) throw error
    return data
}

export const updateSessionStatus = async (sessionId: string, status: string, updates?: Record<string, any>) => {
    const { data, error } = await supabase
        .from('sessions')
        .update({ status, ...updates })
        .eq('id', sessionId)
        .select()
        .single()

    if (error) throw error
    return data
}

// Review helpers
export const createReview = async (reviewData: {
    session_id: string;
    reviewee_id: string;
    rating: number;
    comment?: string;
    is_teacher_review: boolean;
}) => {
    const user = await getCurrentUser()
    if (!user) throw new Error('Not authenticated')

    const { data, error } = await supabase
        .from('reviews')
        .insert({
            ...reviewData,
            reviewer_id: user.id
        })
        .select()
        .single()

    if (error) throw error
    return data
}

// Message helpers
export const getSessionMessages = async (sessionId: string) => {
    const { data, error } = await supabase
        .from('messages')
        .select('*, sender:profiles(*)')
        .eq('session_id', sessionId)
        .order('created_at', { ascending: true })

    if (error) throw error
    return data
}

export const sendMessage = async (sessionId: string, content: string) => {
    const user = await getCurrentUser()
    if (!user) throw new Error('Not authenticated')

    const { data, error } = await supabase
        .from('messages')
        .insert({
            session_id: sessionId,
            sender_id: user.id,
            content
        })
        .select()
        .single()

    if (error) throw error
    return data
}

// Real-time subscriptions
export const subscribeToMessages = (sessionId: string, callback: (message: any) => void) => {
    return supabase
        .channel(`session-${sessionId}`)
        .on('postgres_changes', 
            { event: 'INSERT', schema: 'public', table: 'messages', filter: `session_id=eq.${sessionId}` },
            callback
        )
        .subscribe()
}

export const subscribeToNotifications = (userId: string, callback: (notification: any) => void) => {
    return supabase
        .channel(`user-notifications-${userId}`)
        .on('postgres_changes',
            { event: 'INSERT', schema: 'public', table: 'notifications', filter: `user_id=eq.${userId}` },
            callback
        )
        .subscribe()
}

// Skill discovery
export const searchTeachers = async (skill?: string, query?: string) => {
    let dbQuery = supabase
        .from('profiles')
        .select('*')
        .eq('is_active', true)
        .gt('credits', 0)

    if (skill) {
        dbQuery = dbQuery.contains('skills_teaching', [skill])
    }

    if (query) {
        dbQuery = dbQuery.or(`username.ilike.%${query}%,display_name.ilike.%${query}%,bio.ilike.%${query}%`)
    }

    const { data, error } = await dbQuery.order('rating_average', { ascending: false }).limit(20)
    if (error) throw error
    return data
}

export const getSkillCategories = async () => {
    const { data, error } = await supabase
        .from('skill_categories')
        .select('*')
        .eq('is_active', true)
        .order('sort_order')

    if (error) throw error
    return data
}
