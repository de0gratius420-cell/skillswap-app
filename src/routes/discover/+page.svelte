<script lang="ts">
    import { onMount } from 'svelte'
    import { page } from '$app/stores'
    import { searchTeachers, getSkillCategories } from '../../lib/supabase'
    import TeacherCard from '../../components/TeacherCard.svelte'
    import { searchQuery, selectedSkill } from '../../stores'

    let teachers: any[] = []
    let categories: any[] = []
    let loading = true
    let skillFilter = ''

    onMount(async () => {
        const urlSkill = $page.url.searchParams.get('skill')
        if (urlSkill) {
            skillFilter = urlSkill
            selectedSkill.set(urlSkill)
        }
        await loadData()
    })

    async function loadData() {
        loading = true
        try {
            const [teachersData, categoriesData] = await Promise.all([
                searchTeachers(skillFilter || undefined, $searchQuery || undefined),
                getSkillCategories()
            ])
            teachers = teachersData
            categories = categoriesData
        } catch (e) {
            console.error(e)
        } finally {
            loading = false
        }
    }

    function filterBySkill(skill: string) {
        skillFilter = skill
        selectedSkill.set(skill)
        loadData()
    }

    function handleSearch() {
        searchQuery.set(skillFilter)
        loadData()
    }
</script>

<svelte:head>
    <title>Discover Teachers - SkillSwap</title>
</svelte:head>

<div class="max-w-7xl mx-auto px-4 py-8">
    <h1 class="text-3xl font-bold mb-6">Discover Teachers</h1>

    <!-- Search & Filters -->
    <div class="flex flex-wrap gap-4 mb-8">
        <div class="flex-1 min-w-[300px]">
            <div class="join w-full">
                <input 
                    type="text" 
                    class="input input-bordered join-item flex-1"
                    placeholder="Search by skill, name, or keyword..."
                    bind:value={skillFilter}
                    on:keypress={(e) => e.key === 'Enter' && handleSearch()}
                />
                <button class="btn btn-primary join-item" on:click={handleSearch}>Search</button>
            </div>
        </div>
    </div>

    <!-- Category Pills -->
    <div class="flex flex-wrap gap-2 mb-8">
        <button class="badge badge-lg {skillFilter === '' ? 'badge-primary' : 'badge-outline'}"
                on:click={() => filterBySkill('')}>
            All
        </button>
        {#each categories as cat}
            <button class="badge badge-lg {skillFilter === cat.name ? 'badge-primary' : 'badge-outline'}"
                    on:click={() => filterBySkill(cat.name)}>
                {cat.name}
            </button>
        {/each}
    </div>

    <!-- Results -->
    {#if loading}
        <div class="flex justify-center py-12">
            <span class="loading loading-spinner loading-lg text-primary"></span>
        </div>
    {:else if teachers.length === 0}
        <div class="text-center py-12">
            <p class="text-xl text-gray-500">No teachers found matching your criteria.</p>
            <p class="text-gray-400 mt-2">Try a different skill or browse all categories.</p>
        </div>
    {:else}
        <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {#each teachers as teacher}
                <TeacherCard {teacher} />
            {/each}
        </div>
    {/if}
</div>
