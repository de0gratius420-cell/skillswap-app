<script lang="ts">
    import { onMount } from 'svelte'
    import { supabase } from '../../lib/supabase'
    import { user, toast } from '../../stores'
    import { goto } from '$app/navigation'

    let packages: any[] = []
    let loading = true
    let processing = false

    onMount(async () => {
        try {
            const { data } = await supabase.from('credit_packages').select('*').eq('is_active', true).order('credits')
            packages = data || []
        } catch (e) {
            console.error(e)
        } finally {
            loading = false
        }
    })

    async function buyCredits(packageId: string) {
        if (!$user) {
            toast.add('Please login first', 'warning')
            goto('/login')
            return
        }

        processing = true
        try {
            const { data, error } = await supabase.functions.invoke('stripe-checkout', {
                body: {
                    type: 'credits',
                    package_id: packageId,
                    success_url: `${window.location.origin}/credits/success`,
                    cancel_url: `${window.location.origin}/credits`
                }
            })

            if (error) throw error
            if (data?.url) window.location.href = data.url
        } catch (e: any) {
            toast.add(e.message, 'error')
        } finally {
            processing = false
        }
    }

    const popularBadge = (name: string) => name === 'Popular' || name === 'Pro'
</script>

<svelte:head>
    <title>Buy Credits - SkillSwap</title>
</svelte:head>

<div class="max-w-5xl mx-auto px-4 py-12">
    <div class="text-center mb-12">
        <h1 class="text-4xl font-bold mb-4">Buy Credits</h1>
        <p class="text-xl text-gray-600">Credits are the currency of SkillSwap. Use them to book sessions with top teachers.</p>
        {#if $user}
            <p class="text-lg mt-4">Your balance: <span class="badge badge-primary badge-lg">{$user.credits} credits</span></p>
        {/if}
    </div>

    {#if loading}
        <div class="flex justify-center py-12">
            <span class="loading loading-spinner loading-lg text-primary"></span>
        </div>
    {:else}
        <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
            {#each packages as pkg}
                <div class="card bg-base-100 shadow-xl {popularBadge(pkg.name) ? 'ring-2 ring-primary' : ''}">
                    {#if popularBadge(pkg.name)}
                        <div class="badge badge-primary absolute -top-3 left-1/2 -translate-x-1/2">POPULAR</div>
                    {/if}
                    <div class="card-body items-center text-center">
                        <h2 class="card-title text-2xl">{pkg.name}</h2>
                        <div class="my-4">
                            <span class="text-5xl font-bold text-primary">{pkg.credits + pkg.bonus_credits}</span>
                            <span class="text-lg text-gray-500"> credits</span>
                        </div>
                        {#if pkg.bonus_credits > 0}
                            <p class="text-success text-sm mb-2">+{pkg.bonus_credits} bonus credits!</p>
                        {/if}
                        <p class="text-gray-500 text-sm mb-4">{pkg.description}</p>
                        <div class="text-3xl font-bold mb-4">${pkg.price_usd}</div>
                        <button class="btn btn-primary w-full" on:click={() => buyCredits(pkg.id)} disabled={processing}>
                            {processing ? 'Processing...' : 'Buy Now'}
                        </button>
                    </div>
                </div>
            {/each}
        </div>

        <div class="mt-12 text-center">
            <p class="text-gray-500">Need custom credits? <a href="/contact" class="link link-primary">Contact us</a></p>
        </div>
    {/if}
</div>
