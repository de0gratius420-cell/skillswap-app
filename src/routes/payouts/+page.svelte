<script lang="ts">
    import { onMount } from 'svelte'
    import { supabase } from '../../../lib/supabase'
    import { user, toast } from '../../../stores'
    import { goto } from '$app/navigation'

    let payouts: any[] = []
    let config: any = {}
    let loading = true
    let requestForm = {
        credits_amount: 100,
        method: 'paypal',
        payout_email: ''
    }
    let showForm = false

    onMount(async () => {
        if (!$user) {
            goto('/login')
            return
        }
        await loadData()
    })

    async function loadData() {
        try {
            const [payoutsResult, configResult] = await Promise.all([
                supabase.functions.invoke('payouts', { body: { action: 'list' } }),
                supabase.from('platform_config').select('*').single()
            ])
            payouts = payoutsResult.data?.payouts || []
            config = configResult.data || {}
            requestForm.payout_email = $user?.email || ''
        } catch (e) {
            console.error(e)
        } finally {
            loading = false
        }
    }

    async function requestPayout() {
        try {
            const { data, error } = await supabase.functions.invoke('payouts', {
                body: {
                    action: 'request',
                    credits_amount: requestForm.credits_amount,
                    method: requestForm.method,
                    payout_email: requestForm.payout_email
                }
            })

            if (error) throw error
            toast.add(data?.message || 'Payout requested!', 'success')
            showForm = false
            await loadData()
            await user.refresh()
        } catch (e: any) {
            toast.add(e.message, 'error')
        }
    }

    $: estimatedUsd = requestForm.credits_amount * (config.credit_to_usd_rate || 0.5)
    $: platformFee = estimatedUsd * ((config.platform_fee_percent || 20) / 100)
    $: netAmount = estimatedUsd - platformFee
</script>

<svelte:head>
    <title>Payouts - SkillSwap</title>
</svelte:head>

<div class="max-w-3xl mx-auto px-4 py-8">
    <h1 class="text-3xl font-bold mb-2">Withdraw Earnings</h1>
    <p class="text-gray-500 mb-6">Convert your earned credits to real money</p>

    <div class="card bg-base-100 shadow-lg mb-6">
        <div class="card-body">
            <div class="flex justify-between items-center">
                <div>
                    <p class="text-sm text-gray-500">Available Balance</p>
                    <p class="text-4xl font-bold text-primary">{$user?.credits || 0} credits</p>
                    <p class="text-sm text-gray-500">≈ ${(($user?.credits || 0) * (config.credit_to_usd_rate || 0.5)).toFixed(2)} USD</p>
                </div>
                <button class="btn btn-primary btn-lg" on:click={() => showForm = !showForm}>
                    {showForm ? 'Cancel' : 'Request Payout'}
                </button>
            </div>
        </div>
    </div>

    {#if showForm}
        <div class="card bg-base-100 shadow-lg mb-6">
            <div class="card-body">
                <h2 class="card-title">Request Payout</h2>
                <div class="space-y-4">
                    <div class="form-control">
                        <label class="label"><span class="label-text">Amount (credits)</span></label>
                        <input type="number" class="input input-bordered" bind:value={requestForm.credits_amount} 
                               min={config.min_withdrawal_credits || 100} max={$user?.credits || 0} />
                        <label class="label"><span class="label-text-alt">Min: {config.min_withdrawal_credits || 100} credits</span></label>
                    </div>
                    <div class="form-control">
                        <label class="label"><span class="label-text">Payout Method</span></label>
                        <select class="select select-bordered" bind:value={requestForm.method}>
                            <option value="paypal">PayPal</option>
                            <option value="bank_transfer">Bank Transfer</option>
                            <option value="crypto">Crypto (USDC)</option>
                        </select>
                    </div>
                    <div class="form-control">
                        <label class="label"><span class="label-text">Payout Email/Address</span></label>
                        <input type="text" class="input input-bordered" bind:value={requestForm.payout_email} />
                    </div>

                    <div class="bg-base-200 p-4 rounded-lg">
                        <div class="flex justify-between"><span>Gross Amount:</span><span>${estimatedUsd.toFixed(2)}</span></div>
                        <div class="flex justify-between text-error"><span>Platform Fee ({config.platform_fee_percent || 20}%):</span><span>-${platformFee.toFixed(2)}</span></div>
                        <div class="divider my-1"></div>
                        <div class="flex justify-between font-bold text-success"><span>You Receive:</span><span>${netAmount.toFixed(2)}</span></div>
                    </div>

                    <button class="btn btn-primary w-full" on:click={requestPayout} 
                            disabled={requestForm.credits_amount < (config.min_withdrawal_credits || 100)}>
                        Confirm Payout
                    </button>
                </div>
            </div>
        </div>
    {/if}

    <h2 class="text-xl font-bold mb-4">Payout History</h2>
    {#if payouts.length === 0}
        <p class="text-gray-500">No payouts yet. Start teaching to earn credits!</p>
    {:else}
        <div class="space-y-3">
            {#each payouts as payout}
                <div class="card bg-base-100 shadow-sm">
                    <div class="card-body py-3">
                        <div class="flex justify-between items-center">
                            <div>
                                <p class="font-bold">{payout.credits_amount} credits</p>
                                <p class="text-sm text-gray-500">{payout.method} → {payout.payout_email}</p>
                                <p class="text-xs text-gray-400">{new Date(payout.created_at).toLocaleDateString()}</p>
                            </div>
                            <div class="text-right">
                                <span class="badge 
                                    {payout.status === 'completed' ? 'badge-success' : 
                                     payout.status === 'pending' ? 'badge-warning' : 'badge-error'}">
                                    {payout.status}
                                </span>
                                <p class="text-sm font-bold text-success">${payout.net_amount}</p>
                            </div>
                        </div>
                    </div>
                </div>
            {/each}
        </div>
    {/if}
</div>
