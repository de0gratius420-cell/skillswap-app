<script lang="ts">
    import { onMount } from 'svelte'
    import { user, notifications } from './stores'
    import { supabase, subscribeToNotifications } from './lib/supabase'
    import Header from './components/Header.svelte'

    onMount(async () => {
        const { data: { session } } = await supabase.auth.getSession()
        if (session) {
            await user.refresh()

            // Subscribe to notifications
            const sub = subscribeToNotifications(session.user.id, (payload) => {
                notifications.add(payload.new)
            })

            return () => {
                sub.unsubscribe()
            }
        }
    })
</script>

<Header />

<main class="min-h-screen">
    <slot />
</main>

<footer class="footer footer-center p-10 bg-base-200 text-base-content">
    <div>
        <p class="font-bold text-lg">SkillSwap</p>
        <p>Exchange skills, grow together. Built with ❤️ for learners everywhere.</p>
        <div class="grid grid-flow-col gap-4 mt-4">
            <a href="/about" class="link link-hover">About</a>
            <a href="/terms" class="link link-hover">Terms</a>
            <a href="/privacy" class="link link-hover">Privacy</a>
            <a href="/contact" class="link link-hover">Contact</a>
        </div>
        <p class="text-sm text-gray-500 mt-4">© 2026 SkillSwap. All rights reserved.</p>
    </div>
</footer>
