import { writable, derived } from 'svelte/store'
import { supabase, getCurrentProfile } from './supabase'
import type { Profile, Notification } from '../types'

// User store
function createUserStore() {
    const { subscribe, set, update } = writable<Profile | null>(null)

    return {
        subscribe,
        set,
        update,
        refresh: async () => {
            const profile = await getCurrentProfile()
            set(profile)
            return profile
        },
        clear: () => set(null)
    }
}

export const user = createUserStore()

// Notifications store
function createNotificationsStore() {
    const { subscribe, set, update } = writable<Notification[]>([])

    return {
        subscribe,
        set,
        update,
        add: (notification: Notification) => update(n => [notification, ...n]),
        markRead: (id: string) => update(n => 
            n.map(notif => notif.id === id ? { ...notif, is_read: true } : notif)
        ),
        markAllRead: () => update(n => n.map(notif => ({ ...notif, is_read: true }))),
        unreadCount: derived({ subscribe }, $notifications => 
            $notifications.filter(n => !n.is_read).length
        )
    }
}

export const notifications = createNotificationsStore()

// Loading store
export const isLoading = writable(false)

// Toast/notification store
interface Toast {
    id: string;
    message: string;
    type: 'success' | 'error' | 'info' | 'warning';
    duration?: number;
}

function createToastStore() {
    const { subscribe, update } = writable<Toast[]>([])

    return {
        subscribe,
        add: (message: string, type: Toast['type'] = 'info', duration = 3000) => {
            const id = Math.random().toString(36).substring(7)
            update(toasts => [...toasts, { id, message, type, duration }])
            setTimeout(() => {
                update(toasts => toasts.filter(t => t.id !== id))
            }, duration)
        },
        remove: (id: string) => update(toasts => toasts.filter(t => t.id !== id))
    }
}

export const toast = createToastStore()

// Session filter store
export const sessionFilter = writable<'all' | 'pending' | 'upcoming' | 'completed' | 'cancelled'>('all')

// Search store
export const searchQuery = writable('')
export const selectedSkill = writable<string | null>(null)
