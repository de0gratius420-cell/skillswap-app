<script lang="ts">
    import { goto } from '$app/navigation'
    import { user } from '../stores'
    import { searchTeachers, getSkillCategories } from '../lib/supabase'
    import TeacherCard from '../components/TeacherCard.svelte'
    import { onMount } from 'svelte'

    let featuredTeachers: any[] = []
    let categories: any[] = []
    let searchSkill = ''

    onMount(async () => {
        try {
            [featuredTeachers, categories] = await Promise.all([
                searchTeachers(),
                getSkillCategories()
            ])
        } catch (e) {
            console.error(e)
        }
    })

    async function handleSearch() {
        if (searchSkill) {
            goto(`/discover?skill=${encodeURIComponent(searchSkill)}`)
        }
    }
</script>

<svelte:head>
    <title>SkillSwap - Exchange Skills, Grow Together</title>
</svelte:head>

<!-- Hero Section -->
<div class="hero min-h-[60vh] bg-gradient-to-br from-primary/10 to-secondary/10">
    <div class="hero-content text-center">
        <div class="max-w-3xl">
            <h1 class="text-5xl font-bold mb-6">
                Exchange Skills,<br />
                <span class="text-primary">Grow Together</span>
            </h1>
            <p class="text-xl mb-8 text-gray-600">
                Teach what you know, learn what you don't. A peer-to-peer skill exchange platform 
                where knowledge is the currency.
            </p>

            <div class="flex gap-2 justify-center max-w-lg mx-auto">
                <input 
                    type="text" 
                    placeholder="What do you want to learn? (e.g., Python, Guitar, Spanish)"
                    class="input input-bordered flex-1"
                    bind:value={searchSkill}
                    on:keypress={(e) => e.key === 'Enter' && handleSearch()}
                />
                <button class="btn btn-primary" on:click={handleSearch}>
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                </button>
            </div>

            <div class="mt-6 flex gap-2 justify-center flex-wrap">
                <span class="text-sm text-gray-500">Popular:</span>
                {#each ['JavaScript', 'Python', 'Guitar', 'Spanish', 'Photography'] as skill}
                    <button class="badge badge-outline cursor-pointer hover:badge-primary" 
                            on:click={() => { searchSkill = skill; handleSearch() }}>
                        {skill}
                    </button>
                {/each}
            </div>
        </div>
    </div>
</div>

<!-- How It Works -->
<div class="py-16 px-4 max-w-6xl mx-auto">
    <h2 class="text-3xl font-bold text-center mb-12">How It Works</h2>
    <div class="grid md:grid-cols-3 gap-8">
        <div class="card bg-base-100 shadow-lg">
            <div class="card-body items-center text-center">
                <div class="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mb-4">
                    <span class="text-3xl">🎓</span>
                </div>
                <h3 class="card-title">1. List Your Skills</h3>
                <p>Add skills you can teach. Set your availability and credit rate.</p>
            </div>
        </div>
        <div class="card bg-base-100 shadow-lg">
            <div class="card-body items-center text-center">
                <div class="w-16 h-16 bg-secondary/10 rounded-full flex items-center justify-center mb-4">
                    <span class="text-3xl">🤝</span>
                </div>
                <h3 class="card-title">2. Match & Connect</h3>
                <p>Find someone teaching what you want to learn. Request a session.</p>
            </div>
        </div>
        <div class="card bg-base-100 shadow-lg">
            <div class="card-body items-center text-center">
                <div class="w-16 h-16 bg-accent/10 rounded-full flex items-center justify-center mb-4">
                    <span class="text-3xl">⭐</span>
                </div>
                <h3 class="card-title">3. Exchange & Review</h3>
                <p>Complete your session, earn credits, and build your reputation.</p>
            </div>
        </div>
    </div>
</div>

<!-- Browse by Category -->
<div class="py-16 bg-base-200 px-4">
    <div class="max-w-6xl mx-auto">
        <h2 class="text-3xl font-bold text-center mb-8">Browse by Category</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            {#each categories as category}
                <button class="card bg-base-100 hover:bg-primary hover:text-white transition-colors cursor-pointer"
                        on:click={() => goto(`/discover?category=${category.id}`)}>
                    <div class="card-body items-center text-center p-6">
                        <span class="text-3xl mb-2">{category.icon}</span>
                        <h3 class="font-bold">{category.name}</h3>
                    </div>
                </button>
            {/each}
        </div>
    </div>
</div>

<!-- Featured Teachers -->
<div class="py-16 px-4 max-w-6xl mx-auto">
    <div class="flex justify-between items-center mb-8">
        <h2 class="text-3xl font-bold">Featured Teachers</h2>
        <a href="/discover" class="btn btn-ghost">View All →</a>
    </div>
    <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
        {#each featuredTeachers.slice(0, 6) as teacher}
            <TeacherCard {teacher} />
        {/each}
    </div>
</div>

<!-- CTA Section -->
<div class="py-16 bg-primary text-primary-content px-4">
    <div class="max-w-3xl mx-auto text-center">
        <h2 class="text-3xl font-bold mb-4">Ready to Start Learning?</h2>
        <p class="text-xl mb-8 opacity-90">
            Join thousands of learners exchanging skills. Get 10 free credits when you sign up!
        </p>
        {#if !$user}
            <a href="/login" class="btn btn-secondary btn-lg">Get Started Free</a>
        {:else}
            <a href="/discover" class="btn btn-secondary btn-lg">Find a Teacher</a>
        {/if}
    </div>
</div>
