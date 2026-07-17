<script lang="ts">
    import { onMount } from 'svelte'
    import { supabase } from '../../lib/supabase'
    import { user, toast } from '../../stores'
    import { goto } from '$app/navigation'

    let stats: any = null
    let topTeachers: any[] = []
    let recentTransactions: any[] = []
    let pendingPayouts: any[] = []
    let openDisputes: any[] = []
    let auditLogs: any[] = []
    let loading = true
    let isAdmin = false
    let activeTab = 'overview'
    let config: any = {}

    onMount(async () => {
        await checkAdmin()
        if (isAdmin) await loadAllData()
    })

    async function checkAdmin() {
        const { data: admin } = await supabase.from('admin_users').select('*').eq('user_id', $user?.id).single()
        isAdmin = !!admin
        if (!isAdmin) {
            toast.add('Access denied', 'error')
            goto('/')
        }
    }

    async function loadAllData() {
        try {
            const [statsResult, teachersResult, transactionsResult, payoutsResult, disputesResult, auditResult, configResult] = await Promise.all([
                supabase.rpc('get_platform_stats'),
                supabase.rpc('get_top_teachers', { limit_count: 10 }),
                supabase.from('credit_transactions').select('*, user:profiles(*)').order('created_at', { ascending: false }).limit(50),
                supabase.from('payouts').select('*, user:profiles(*)').eq('status', 'pending').order('created_at', { ascending: false }),
                supabase.from('disputes').select('*, session:sessions(*), opener:profiles!disputes_opened_by_fkey(*), respondent:profiles!disputes_respondent_id_fkey(*)').eq('status', 'open').order('created_at', { ascending: false }),
                supabase.from('audit_log').select('*').order('created_at', { ascending: false }).limit(100),
                supabase.from('platform_config').select('*').single()
            ])

            stats = statsResult.data?.[0]
            topTeachers = teachersResult.data || []
            recentTransactions = transactionsResult.data || []
            pendingPayouts = payoutsResult.data || []
            openDisputes = disputesResult.data || []
            auditLogs = auditResult.data || []
            config = configResult.data || {}
        } catch (e) {
            console.error(e)
        } finally {
            loading = false
        }
    }

    async function processPayout(payoutId: string, action: 'complete' | 'reject', reason?: string) {
        try {
            const { error } = await supabase.from('payouts').update({
                status: action === 'complete' ? 'completed' : 'rejected',
                rejection_reason: reason,
                processed_at: new Date().toISOString()
            }).eq('id', payoutId)

            if (error) throw error
            toast.add(`Payout ${action === 'complete' ? 'completed' : 'rejected'}`, 'success')
            await loadAllData()
        } catch (e: any) {
            toast.add(e.message, 'error')
        }
    }

    async function resolveDispute(disputeId: string, resolution: 'resolved_buyer' | 'resolved_seller', notes: string) {
        try {
            const { data: dispute } = await supabase.from('disputes').select('*').eq('id', disputeId).single()

            // If resolving for buyer, refund credits
            if (resolution === 'resolved_buyer') {
                const { data: session } = await supabase.from('sessions').select('*').eq('id', dispute.session_id).single()
                const { data: profile } = await supabase.from('profiles').select('credits').eq('id', session.learner_id).single()

                await supabase.from('profiles').update({ credits: profile.credits + session.credits_cost }).eq('id', session.learner_id)
                await supabase.from('credit_transactions').insert({
                    user_id: session.learner_id,
                    amount: session.credits_cost,
                    type: 'refund',
                    description: `Dispute refund for session #${session.id.substring(0, 8)}`,
                    balance_after: profile.credits + session.credits_cost
                })
            }

            await supabase.from('disputes').update({
                status: resolution,
                resolution_notes: notes,
                resolved_by: $user?.id,
                resolved_at: new Date().toISOString()
            }).eq('id', disputeId)

            toast.add('Dispute resolved', 'success')
            await loadAllData()
        } catch (e: any) {
            toast.add(e.message, 'error')
        }
    }

    async function updateConfig() {
        try {
            const { error } = await supabase.from('platform_config').update({
                platform_fee_percent: config.platform_fee_percent,
                credit_to_usd_rate: config.credit_to_usd_rate,
                min_withdrawal_credits: config.min_withdrawal_credits,
                featured_listing_cost_credits: config.featured_listing_cost_credits,
                dispute_window_hours: config.dispute_window_hours
            }).eq('id', 1)

            if (error) throw error
            toast.add('Platform configuration updated', 'success')
        } catch (e: any) {
            toast.add(e.message, 'error')
        }
    }

    async function refreshRevenue() {
        await supabase.rpc('refresh_revenue_summary')
        toast.add('Revenue data refreshed', 'success')
    }

    const formatCurrency = (val: number) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val)
    const formatNumber = (val: number) => new Intl.NumberFormat('en-US').format(val)
</script>

<svelte:head>
    <title>Admin Dashboard - SkillSwap</title>
</svelte:head>

{#if !isAdmin}
    <div class="flex justify-center py-12">
        <span class="loading loading-spinner loading-lg"></span>
    </div>
{:else}
    <div class="min-h-screen bg-base-200">
        <!-- Admin Header -->
        <div class="bg-base-100 shadow-lg">
            <div class="max-w-7xl mx-auto px-4 py-4">
                <div class="flex justify-between items-center">
                    <h1 class="text-2xl font-bold">🛡️ Admin Dashboard</h1>
                    <div class="flex gap-2">
                        <button class="btn btn-sm btn-ghost" on:click={refreshRevenue}>🔄 Refresh</button>
                        <a href="/" class="btn btn-sm btn-ghost">Exit Admin</a>
                    </div>
                </div>
            </div>
        </div>

        <!-- Tabs -->
        <div class="max-w-7xl mx-auto px-4 py-4">
            <div class="tabs tabs-boxed bg-base-100">
                <button class="tab {activeTab === 'overview' ? 'tab-active' : ''}" on:click={() => activeTab = 'overview'}>📊 Overview</button>
                <button class="tab {activeTab === 'teachers' ? 'tab-active' : ''}" on:click={() => activeTab = 'teachers'}>👨‍🏫 Teachers</button>
                <button class="tab {activeTab === 'transactions' ? 'tab-active' : ''}" on:click={() => activeTab = 'transactions'}>💳 Transactions</button>
                <button class="tab {activeTab === 'payouts' ? 'tab-active' : ''}" on:click={() => activeTab = 'payouts'}>💰 Payouts ({pendingPayouts.length})</button>
                <button class="tab {activeTab === 'disputes' ? 'tab-active' : ''}" on:click={() => activeTab = 'disputes'}>⚠️ Disputes ({openDisputes.length})</button>
                <button class="tab {activeTab === 'settings' ? 'tab-active' : ''}" on:click={() => activeTab = 'settings'}>⚙️ Settings</button>
                <button class="tab {activeTab === 'audit' ? 'tab-active' : ''}" on:click={() => activeTab = 'audit'}>📋 Audit</button>
            </div>
        </div>

        <div class="max-w-7xl mx-auto px-4 pb-12">
            {#if loading}
                <div class="flex justify-center py-12">
                    <span class="loading loading-spinner loading-lg text-primary"></span>
                </div>
            {:else}
                <!-- OVERVIEW TAB -->
                {#if activeTab === 'overview'}
                    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
                        <div class="stat bg-base-100 shadow-lg rounded-xl">
                            <div class="stat-title">Total Users</div>
                            <div class="stat-value text-primary">{formatNumber(stats?.total_users || 0)}</div>
                            <div class="stat-desc">{formatNumber(stats?.active_users || 0)} active</div>
                        </div>
                        <div class="stat bg-base-100 shadow-lg rounded-xl">
                            <div class="stat-title">Sessions</div>
                            <div class="stat-value">{formatNumber(stats?.total_sessions || 0)}</div>
                            <div class="stat-desc text-success">{formatNumber(stats?.completed_sessions || 0)} completed</div>
                        </div>
                        <div class="stat bg-base-100 shadow-lg rounded-xl">
                            <div class="stat-title">Credits in Circulation</div>
                            <div class="stat-value text-accent">{formatNumber(stats?.total_credits_in_circulation || 0)}</div>
                            <div class="stat-desc">{formatNumber(stats?.total_credits_purchased || 0)} purchased</div>
                        </div>
                        <div class="stat bg-base-100 shadow-lg rounded-xl">
                            <div class="stat-title">Platform Revenue</div>
                            <div class="stat-value text-success">{formatNumber(stats?.total_platform_fees || 0)}</div>
                            <div class="stat-desc">credits in fees</div>
                        </div>
                    </div>

                    <div class="grid md:grid-cols-2 gap-6">
                        <div class="card bg-base-100 shadow-lg">
                            <div class="card-body">
                                <h2 class="card-title">Quick Actions</h2>
                                <div class="grid grid-cols-2 gap-2">
                                    <button class="btn btn-primary" on:click={() => activeTab = 'payouts'}>Process Payouts</button>
                                    <button class="btn btn-secondary" on:click={() => activeTab = 'disputes'}>Resolve Disputes</button>
                                    <button class="btn btn-accent" on:click={() => activeTab = 'settings'}>Update Fees</button>
                                    <button class="btn btn-info" on:click={() => activeTab = 'teachers'}>View Top Teachers</button>
                                </div>
                            </div>
                        </div>

                        <div class="card bg-base-100 shadow-lg">
                            <div class="card-body">
                                <h2 class="card-title">System Health</h2>
                                <div class="space-y-2">
                                    <div class="flex justify-between">
                                        <span>Pending Payouts</span>
                                        <span class="badge {stats?.pending_payouts > 0 ? 'badge-warning' : 'badge-success'}">{stats?.pending_payouts || 0}</span>
                                    </div>
                                    <div class="flex justify-between">
                                        <span>Open Disputes</span>
                                        <span class="badge {stats?.open_disputes > 0 ? 'badge-error' : 'badge-success'}">{stats?.open_disputes || 0}</span>
                                    </div>
                                    <div class="flex justify-between">
                                        <span>Avg Rating</span>
                                        <span class="badge badge-primary">★ {stats?.avg_session_rating?.toFixed(1) || 0}</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                {/if}

                <!-- TEACHERS TAB -->
                {#if activeTab === 'teachers'}
                    <div class="card bg-base-100 shadow-lg">
                        <div class="card-body">
                            <h2 class="card-title">Top 10 Teachers by Earnings</h2>
                            <div class="overflow-x-auto">
                                <table class="table table-zebra">
                                    <thead>
                                        <tr>
                                            <th>Rank</th>
                                            <th>Teacher</th>
                                            <th>Skills</th>
                                            <th>Sessions</th>
                                            <th>Rating</th>
                                            <th>Total Earned</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {#each topTeachers as teacher, i}
                                            <tr>
                                                <td class="font-bold">#{i + 1}</td>
                                                <td>
                                                    <div class="flex items-center gap-2">
                                                        <div class="avatar">
                                                            <div class="w-8 rounded-full"><img src="/default-avatar.png" alt="" /></div>
                                                        </div>
                                                        <span>{teacher.display_name || teacher.username}</span>
                                                    </div>
                                                </td>
                                                <td>
                                                    {#each teacher.skills_teaching?.slice(0, 2) || [] as skill}
                                                        <span class="badge badge-sm badge-primary">{skill}</span>
                                                    {/each}
                                                </td>
                                                <td>{teacher.sessions_taught}</td>
                                                <td>★ {teacher.avg_rating}</td>
                                                <td class="font-bold text-success">{teacher.total_earned} credits</td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                {/if}

                <!-- TRANSACTIONS TAB -->
                {#if activeTab === 'transactions'}
                    <div class="card bg-base-100 shadow-lg">
                        <div class="card-body">
                            <h2 class="card-title">Recent Transactions</h2>
                            <div class="overflow-x-auto">
                                <table class="table table-zebra table-sm">
                                    <thead>
                                        <tr>
                                            <th>Time</th>
                                            <th>User</th>
                                            <th>Type</th>
                                            <th>Amount</th>
                                            <th>Description</th>
                                            <th>Balance After</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {#each recentTransactions as tx}
                                            <tr>
                                                <td class="text-xs">{new Date(tx.created_at).toLocaleString()}</td>
                                                <td>{tx.user?.username}</td>
                                                <td>
                                                    <span class="badge badge-sm 
                                                        {tx.type === 'earn' ? 'badge-success' : 
                                                         tx.type === 'spend' ? 'badge-error' : 
                                                         tx.type === 'purchase' ? 'badge-primary' : 
                                                         tx.type === 'bonus' ? 'badge-info' : 'badge-ghost'}">
                                                        {tx.type}
                                                    </span>
                                                </td>
                                                <td class="font-bold {tx.amount > 0 ? 'text-success' : 'text-error'}">{tx.amount > 0 ? '+' : ''}{tx.amount}</td>
                                                <td class="text-sm">{tx.description}</td>
                                                <td>{tx.balance_after}</td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                {/if}

                <!-- PAYOUTS TAB -->
                {#if activeTab === 'payouts'}
                    <div class="card bg-base-100 shadow-lg">
                        <div class="card-body">
                            <h2 class="card-title">Pending Payouts</h2>
                            {#if pendingPayouts.length === 0}
                                <p class="text-gray-500 py-4">No pending payouts 🎉</p>
                            {:else}
                                <div class="space-y-4">
                                    {#each pendingPayouts as payout}
                                        <div class="border border-base-300 rounded-lg p-4">
                                            <div class="flex justify-between items-start">
                                                <div>
                                                    <p class="font-bold">{payout.user?.display_name || payout.user?.username}</p>
                                                    <p class="text-sm text-gray-500">{payout.credits_amount} credits → {formatCurrency(payout.usd_amount)}</p>
                                                    <p class="text-sm">Net: <span class="font-bold text-success">{formatCurrency(payout.net_amount)}</span> (fee: {formatCurrency(payout.platform_fee_deducted)})</p>
                                                    <p class="text-xs text-gray-400">Method: {payout.method} | {payout.payout_email}</p>
                                                </div>
                                                <div class="flex gap-2">
                                                    <button class="btn btn-success btn-sm" on:click={() => processPayout(payout.id, 'complete')}>✓ Pay</button>
                                                    <button class="btn btn-error btn-sm" on:click={() => processPayout(payout.id, 'reject', 'Rejected by admin')}>✗ Reject</button>
                                                </div>
                                            </div>
                                        </div>
                                    {/each}
                                </div>
                            {/if}
                        </div>
                    </div>
                {/if}

                <!-- DISPUTES TAB -->
                {#if activeTab === 'disputes'}
                    <div class="space-y-4">
                        {#each openDisputes as dispute}
                            <div class="card bg-base-100 shadow-lg">
                                <div class="card-body">
                                    <div class="flex justify-between items-start">
                                        <div>
                                            <h3 class="font-bold">Dispute #{dispute.id.substring(0, 8)}</h3>
                                            <p class="text-sm">Session: {dispute.session_id?.substring(0, 8)}</p>
                                            <p class="text-sm">Opened by: {dispute.opener?.username} | Respondent: {dispute.respondent?.username}</p>
                                            <p class="mt-2"><span class="font-semibold">Reason:</span> {dispute.reason}</p>
                                            <p class="text-sm text-gray-600 mt-1">{dispute.description}</p>
                                        </div>
                                        <span class="badge badge-error">OPEN</span>
                                    </div>
                                    <div class="flex gap-2 mt-4">
                                        <button class="btn btn-success btn-sm" on:click={() => resolveDispute(dispute.id, 'resolved_buyer', 'Resolved in favor of buyer - credits refunded')}>
                                            Refund Buyer
                                        </button>
                                        <button class="btn btn-error btn-sm" on:click={() => resolveDispute(dispute.id, 'resolved_seller', 'Resolved in favor of seller - no refund')}>
                                            Side with Seller
                                        </button>
                                    </div>
                                </div>
                            </div>
                        {/each}
                    </div>
                {/if}

                <!-- SETTINGS TAB -->
                {#if activeTab === 'settings'}
                    <div class="card bg-base-100 shadow-lg max-w-2xl">
                        <div class="card-body">
                            <h2 class="card-title">Platform Configuration</h2>
                            <div class="space-y-4">
                                <div class="form-control">
                                    <label class="label"><span class="label-text">Platform Fee (%)</span></label>
                                    <input type="number" class="input input-bordered" bind:value={config.platform_fee_percent} min="0" max="100" step="0.01" />
                                    <label class="label"><span class="label-text-alt">Percentage taken from each session</span></label>
                                </div>
                                <div class="form-control">
                                    <label class="label"><span class="label-text">Credit to USD Rate</span></label>
                                    <input type="number" class="input input-bordered" bind:value={config.credit_to_usd_rate} min="0.01" step="0.01" />
                                    <label class="label"><span class="label-text-alt">1 credit = ${config.credit_to_usd_rate} USD</span></label>
                                </div>
                                <div class="form-control">
                                    <label class="label"><span class="label-text">Min Withdrawal (credits)</span></label>
                                    <input type="number" class="input input-bordered" bind:value={config.min_withdrawal_credits} min="1" />
                                </div>
                                <div class="form-control">
                                    <label class="label"><span class="label-text">Featured Listing Cost (credits)</span></label>
                                    <input type="number" class="input input-bordered" bind:value={config.featured_listing_cost_credits} min="1" />
                                </div>
                                <div class="form-control">
                                    <label class="label"><span class="label-text">Dispute Window (hours)</span></label>
                                    <input type="number" class="input input-bordered" bind:value={config.dispute_window_hours} min="1" />
                                </div>
                                <button class="btn btn-primary" on:click={updateConfig}>Save Changes</button>
                            </div>
                        </div>
                    </div>
                {/if}

                <!-- AUDIT TAB -->
                {#if activeTab === 'audit'}
                    <div class="card bg-base-100 shadow-lg">
                        <div class="card-body">
                            <h2 class="card-title">Audit Log</h2>
                            <div class="overflow-x-auto">
                                <table class="table table-zebra table-sm">
                                    <thead>
                                        <tr><th>Time</th><th>Table</th><th>Action</th><th>Record</th><th>By</th></tr>
                                    </thead>
                                    <tbody>
                                        {#each auditLogs as log}
                                            <tr>
                                                <td class="text-xs">{new Date(log.created_at).toLocaleString()}</td>
                                                <td><span class="badge badge-sm">{log.table_name}</span></td>
                                                <td>
                                                    <span class="badge badge-sm 
                                                        {log.action === 'INSERT' ? 'badge-success' : log.action === 'UPDATE' ? 'badge-warning' : 'badge-error'}">
                                                        {log.action}
                                                    </span>
                                                </td>
                                                <td class="text-xs font-mono">{log.record_id?.substring(0, 8)}</td>
                                                <td class="text-xs">{log.performed_by?.substring(0, 8)}</td>
                                            </tr>
                                        {/each}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                {/if}
            {/if}
        </div>
    </div>
{/if}
