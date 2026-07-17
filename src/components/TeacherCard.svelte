<script lang="ts">
    import type { Profile } from '../types'
    import { goto } from '$app/navigation'

    export let teacher: Profile

    function viewProfile() {
        goto(`/profile/${teacher.username}`)
    }
</script>

<div class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow cursor-pointer" on:click={viewProfile}>
    <div class="card-body">
        <div class="flex items-start gap-4">
            <div class="avatar">
                <div class="w-16 rounded-full ring ring-primary ring-offset-base-100 ring-offset-2">
                    <img src={teacher.avatar_url || '/default-avatar.png'} alt={teacher.display_name || teacher.username} />
                </div>
            </div>
            <div class="flex-1">
                <h3 class="card-title text-lg">
                    {teacher.display_name || teacher.username}
                    {#if teacher.is_verified}
                        <span class="badge badge-primary badge-sm">✓ Verified</span>
                    {/if}
                </h3>
                <p class="text-sm text-gray-500">{teacher.location || 'Online'}</p>
                <div class="flex items-center gap-1 mt-1">
                    <span class="text-yellow-500">★</span>
                    <span class="font-semibold">{teacher.rating_average}</span>
                    <span class="text-sm text-gray-400">({teacher.total_reviews_received} reviews)</span>
                </div>
            </div>
            <div class="text-right">
                <span class="badge badge-outline badge-primary">{teacher.credits} credits</span>
            </div>
        </div>

        <p class="text-sm mt-2 line-clamp-2">{teacher.bio || 'No bio yet'}</p>

        <div class="flex flex-wrap gap-2 mt-3">
            {#each teacher.skills_teaching.slice(0, 4) as skill}
                <span class="badge badge-secondary badge-sm">{skill}</span>
            {/each}
            {#if teacher.skills_teaching.length > 4}
                <span class="badge badge-ghost badge-sm">+{teacher.skills_teaching.length - 4}</span>
            {/if}
        </div>

        <div class="card-actions justify-end mt-4">
            <button class="btn btn-primary btn-sm" on:click|stopPropagation={() => goto(`/request/${teacher.id}`)}>
                Request Session
            </button>
        </div>
    </div>
</div>
