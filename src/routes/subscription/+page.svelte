<script lang="ts">
    import { onMount } from 'svelte'
    import { supabase } from '../../lib/supabase'
    import { user, toast } from '../../stores'
    import { goto } from '$app/navigation'

    let plans: any[] = []
    let currentPlan: any = null
    let loading = true
    let yearly = false

    onMount(async () => {
        try {
            const { data: plansData } = await supabase.from('subscription_plans').select('*').eq('is_active', true).order('price_monthly_usd')
            plans = plansData || []

            if ($user) {
                const { data: sub } = await supabase.from('user_subscriptions').select('*, plan:subscription_plans(*)').eq('user_id', $user.id).eq('status', 'active').single()
                currentPlan = sub?.plan
            }
        } catch (e) {
            console.error(e)
        } finally {
            loading = false
        }
    })

    async function subscribe(planId: string) {
        if (!$user) {
            toast.add('Please login first', 'warning')
            goto('/login')
            return
        }

        try {
            const { data, error } = await supabase.functions.invoke('stripe-checkout', {
                body: {
                    type: 'subscription',
                    plan_id: planId,
                    success_url: `${window.location.origin}/subscription/success`,
                    cancel_url: `${window.location.origin}/subscription`
                }
            })

            if (error) throw error
            if (data?.url) window.location.href = data.url
        } catch (e: any) {
            toast.add(e.message, 'error')
        }
    }

    const planColors = ['bg-base-100', 'bg-primary/5', 'bg-secondary/5', 'bg-accent/5']
    const planBadges = ['', 'badge-primary', 'badge-secondary', 'badge-accent']
</script>

<svelte:head>
    <title>Subscription Plans - SkillSwap</title>
</svelte:head>

<div class="max-w-6xl mx-auto px-4 py-12">
    <div class="text-center mb-12">
        <h1 class="text-4xl font-bold mb-4">Upgrade Your Experience</h1>
        <p class="text-xl text-gray-600">Choose the plan that fits your learning goals</p>

        <div class="flex justify-center gap-4 mt-6">
            <button class="btn {yearly ? 'btn-ghost' : 'btn-primary'}" on:click={() => yearly = false}>Monthly</button>
            <button class="btn {yearly ? 'btn-primary' : 'btn-ghost'}" on:click={() => yearly = true}>
                Yearly <span class="badge badge-sm badge-success ml-2">Save 17%</span>
            </button>
        </div>
    </div>

    {#if loading}
        <div class="flex justify-center py-12">
            <span class="loading loading-spinner loading-lg text-primary"></span>
        </div>
    {:else}
        <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
            {#each plans as plan, i}
                <div class="card {planColors[i]} shadow-xl {plan.id === currentPlan?.id ? 'ring-2 ring-success' : ''}">
                    {#if plan.id === currentPlan?.id}
                        <div class="badge badge-success absolute -top-3 left-1/2 -translate-x-1/2">CURRENT PLAN</div>
                    {/if}
                    <div class="card-body">
                        <h2 class="card-title text-2xl">{plan.name}</h2>
                        <div class="my-4">
                            <span class="text-4xl font-bold">${yearly && plan.price_yearly_usd ? (plan.price_yearly_usd / 12).toFixed(2) : plan.price_monthly_usd}</span>
                            <span class="text-gray-500">/mo</span>
                        </div>
                        {#if yearly && plan.price_yearly_usd}
                            <p class="text-sm text-success">${plan.price_yearly_usd}/year billed annually</p>
                        {/if}

                        <div class="divider"></div>

                        <ul class="space-y-2 text-sm">
                            {#each plan.features as feature}
                                <li class="flex items-center gap-2">
                                    <span class="text-success">✓</span>
                                    <span>{feature}</span>
                                </li>
                            {/each}
                        </ul>

                        {#if plan.credits_included_monthly > 0}
                            <div class="mt-4 p-3 bg-base-200 rounded-lg">
                                <p class="text-sm font-semibold">{plan.credits_included_monthly} credits/month included</p>
                            </div>
                        {/if}

                        {#if plan.commission_discount_percent > 0}
                            <div class="mt-2 p-3 bg-success/10 rounded-lg">
                                <p class="text-sm text-success font-semibold">{plan.commission_discount_percent}% lower platform fees</p>
                            </div>
                        {/if}

                        <div class="card-actions mt-4">
                            {#if plan.price_monthly_usd === 0}
                                <button class="btn btn-ghost w-full" disabled>Current Plan</button>
                            {:else}
                                <button class="btn btn-primary w-full" on:click={() => subscribe(plan.id)}>
                                    {plan.id === currentPlan?.id ? 'Manage' : 'Subscribe'}
                                </button>
                            {/if}
                        </div>
                    </div>
                </div>
            {/each}
        </div>
    {/if}
</div>
