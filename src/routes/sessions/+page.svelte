<script lang="ts">
    import { onMount } from 'svelte'
    import { getMySessions } from '../../lib/supabase'
    import { user, sessionFilter } from '../../stores'
    import SessionCard from '../../components/SessionCard.svelte'

    let sessions: any[] = []
    let loading = true

    onMount(async () => {
        await loadSessions()
    })

    async function loadSessions() {
        loading = true
        try {
            const status = $sessionFilter === 'all' ? undefined : $sessionFilter
            sessions = await getMySessions(status)
        } catch (e) {
            console.error(e)
        } finally {
            loading = false
        }
    }

    $: if ($sessionFilter) loadSessions()

    const filters = [
        { key: 'all', label: 'All', icon: '📋' },
        { key: 'pending', label: 'Pending', icon: '⏳' },
        { key: 'upcoming', label: 'Upcoming', icon: '📅' },
        { key: 'completed', label: 'Completed', icon: '✅' },
        { key: 'cancelled', label: 'Cancelled', icon: '❌' }
    ]
</script>

<svelte:head>
    <title>My Sessions - SkillSwap</title>
</svelte:head>

<div class="max-w-5xl mx-auto px-4 py-8">
    <h1 class="text-3xl font-bold mb-6">My Sessions</h1>

    <!-- Filter Tabs -->
    <div class="tabs tabs-boxed mb-6">
        {#each filters as filter}
            <button 
                class="tab {$sessionFilter === filter.key ? 'tab-active' : ''}"
                on:click={() => sessionFilter.set(filter.key)}
            >
                {filter.icon} {filter.label}
            </button>
        {/each}
    </div>

    {#if loading}
        <div class="flex justify-center py-12">
            <span class="loading loading-spinner loading-lg text-primary"></span>
        </div>
    {:else if sessions.length === 0}
        <div class="text-center py-12 bg-base-200 rounded-xl">
            <p class="text-4xl mb-4">📚</p>
            <p class="text-xl text-gray-500">No sessions yet</p>
            <a href="/discover" class="btn btn-primary mt-4">Find a Teacher</a>
        </div>
    {:else}
        <div class="space-y-4">
            {#each sessions as session}
                <SessionCard 
                    {session} 
                    isTeacher={session.teacher_id === $user?.id}
                />
            {/each}
        </div>
    {/if}
</div>
