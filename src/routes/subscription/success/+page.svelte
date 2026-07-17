<script>
    import { onMount } from 'svelte'
    import { goto } from '$app/navigation'
    import { toast } from '../stores'

    onMount(() => {
        toast.add('Subscription activated! Enjoy your premium features.', 'success')
        setTimeout(() => goto('/'), 3000)
    })
</script>

<div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
        <div class="text-6xl mb-4">⭐</div>
        <h1 class="text-3xl font-bold mb-2">Welcome to Pro!</h1>
        <p class="text-gray-500">Your subscription is now active. Enjoy premium features!</p>
        <p class="text-sm text-gray-400 mt-4">Redirecting...</p>
    </div>
</div>
