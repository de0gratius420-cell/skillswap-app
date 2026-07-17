<script>
    import { onMount } from 'svelte'
    import { goto } from '$app/navigation'
    import { toast } from '../stores'

    onMount(() => {
        toast.add('Payment successful! Credits added to your account.', 'success')
        setTimeout(() => goto('/credits'), 3000)
    })
</script>

<div class="min-h-screen flex items-center justify-center">
    <div class="text-center">
        <div class="text-6xl mb-4">🎉</div>
        <h1 class="text-3xl font-bold mb-2">Payment Successful!</h1>
        <p class="text-gray-500">Your credits have been added to your account.</p>
        <p class="text-sm text-gray-400 mt-4">Redirecting...</p>
    </div>
</div>
