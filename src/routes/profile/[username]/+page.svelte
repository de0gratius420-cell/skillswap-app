<script lang="ts">
    import { onMount } from 'svelte'
    import { page } from '$app/stores'
    import { supabase } from '../../lib/supabase'
    import { user, toast } from '../../stores'

    let profile: any = null
    let reviews: any[] = []
    let loading = true
    let isEditing = false
    let editForm: any = {}

    onMount(async () => {
        const username = $page.params.username
        await loadProfile(username)
    })

    async function loadProfile(username: string) {
        loading = true
        try {
            const { data: profileData } = await supabase
                .from('profiles')
                .select('*')
                .eq('username', username)
                .single()

            if (profileData) {
                profile = profileData
                editForm = { ...profileData }

                const { data: reviewsData } = await supabase
                    .from('reviews')
                    .select('*, reviewer:profiles!reviews_reviewer_id_fkey(*)')
                    .eq('reviewee_id', profileData.id)
                    .order('created_at', { ascending: false })

                reviews = reviewsData || []
            }
        } catch (e) {
            console.error(e)
        } finally {
            loading = false
        }
    }

    async function saveProfile() {
        try {
            const { error } = await supabase
                .from('profiles')
                .update({
                    display_name: editForm.display_name,
                    bio: editForm.bio,
                    location: editForm.location,
                    skills_teaching: editForm.skills_teaching,
                    skills_learning: editForm.skills_learning,
                    timezone: editForm.timezone
                })
                .eq('id', $user?.id)

            if (error) throw error

            profile = { ...profile, ...editForm }
            isEditing = false
            toast.add('Profile updated!', 'success')
        } catch (e: any) {
            toast.add(e.message, 'error')
        }
    }

    function addSkill(type: 'teaching' | 'learning') {
        const skill = prompt(`Enter a skill to ${type === 'teaching' ? 'teach' : 'learn'}:`)
        if (skill) {
            if (type === 'teaching') {
                editForm.skills_teaching = [...(editForm.skills_teaching || []), skill]
            } else {
                editForm.skills_learning = [...(editForm.skills_learning || []), skill]
            }
        }
    }

    function removeSkill(type: 'teaching' | 'learning', index: number) {
        if (type === 'teaching') {
            editForm.skills_teaching = editForm.skills_teaching.filter((_: any, i: number) => i !== index)
        } else {
            editForm.skills_learning = editForm.skills_learning.filter((_: any, i: number) => i !== index)
        }
    }

    $: isOwnProfile = $user?.id === profile?.id
</script>

<svelte:head>
    <title>{profile?.display_name || profile?.username || 'Profile'} - SkillSwap</title>
</svelte:head>

{#if loading}
    <div class="flex justify-center py-12">
        <span class="loading loading-spinner loading-lg text-primary"></span>
    </div>
{:else if profile}
    <div class="max-w-4xl mx-auto px-4 py-8">
        <!-- Profile Header -->
        <div class="card bg-base-100 shadow-xl mb-6">
            <div class="card-body">
                <div class="flex items-start gap-6">
                    <div class="avatar">
                        <div class="w-24 rounded-full ring ring-primary ring-offset-base-100 ring-offset-2">
                            <img src={profile.avatar_url || '/default-avatar.png'} alt={profile.display_name} />
                        </div>
                    </div>
                    <div class="flex-1">
                        <div class="flex justify-between items-start">
                            <div>
                                <h1 class="text-3xl font-bold">
                                    {profile.display_name || profile.username}
                                    {#if profile.is_verified}
                                        <span class="badge badge-primary ml-2">✓ Verified</span>
                                    {/if}
                                </h1>
                                <p class="text-gray-500">@{profile.username}</p>
                            </div>
                            {#if isOwnProfile}
                                <button class="btn btn-ghost btn-sm" on:click={() => isEditing = !isEditing}>
                                    {isEditing ? 'Cancel' : 'Edit'}
                                </button>
                            {:else}
                                <a href="/request/{profile.id}" class="btn btn-primary">Request Session</a>
                            {/if}
                        </div>

                        <div class="flex gap-4 mt-4">
                            <div class="stat bg-base-200 rounded-lg p-3">
                                <div class="stat-value text-2xl text-primary">{profile.rating_average}</div>
                                <div class="stat-title text-xs">Rating</div>
                            </div>
                            <div class="stat bg-base-200 rounded-lg p-3">
                                <div class="stat-value text-2xl">{profile.total_sessions_taught}</div>
                                <div class="stat-title text-xs">Taught</div>
                            </div>
                            <div class="stat bg-base-200 rounded-lg p-3">
                                <div class="stat-value text-2xl">{profile.total_sessions_learned}</div>
                                <div class="stat-title text-xs">Learned</div>
                            </div>
                            <div class="stat bg-base-200 rounded-lg p-3">
                                <div class="stat-value text-2xl text-accent">{profile.credits}</div>
                                <div class="stat-title text-xs">Credits</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        {#if isEditing}
            <!-- Edit Form -->
            <div class="card bg-base-100 shadow-xl mb-6">
                <div class="card-body">
                    <h2 class="card-title">Edit Profile</h2>
                    <div class="space-y-4">
                        <div class="form-control">
                            <label class="label"><span class="label-text">Display Name</span></label>
                            <input type="text" class="input input-bordered" bind:value={editForm.display_name} />
                        </div>
                        <div class="form-control">
                            <label class="label"><span class="label-text">Bio</span></label>
                            <textarea class="textarea textarea-bordered" bind:value={editForm.bio} rows="3"></textarea>
                        </div>
                        <div class="form-control">
                            <label class="label"><span class="label-text">Location</span></label>
                            <input type="text" class="input input-bordered" bind:value={editForm.location} />
                        </div>
                        <div class="form-control">
                            <label class="label"><span class="label-text">Skills Teaching</span></label>
                            <div class="flex flex-wrap gap-2 mb-2">
                                {#each editForm.skills_teaching || [] as skill, i}
                                    <span class="badge badge-primary gap-1">
                                        {skill}
                                        <button on:click={() => removeSkill('teaching', i)}>×</button>
                                    </span>
                                {/each}
                            </div>
                            <button class="btn btn-outline btn-sm w-fit" on:click={() => addSkill('teaching')}>
                                + Add Skill
                            </button>
                        </div>
                        <div class="form-control">
                            <label class="label"><span class="label-text">Skills Learning</span></label>
                            <div class="flex flex-wrap gap-2 mb-2">
                                {#each editForm.skills_learning || [] as skill, i}
                                    <span class="badge badge-secondary gap-1">
                                        {skill}
                                        <button on:click={() => removeSkill('learning', i)}>×</button>
                                    </span>
                                {/each}
                            </div>
                            <button class="btn btn-outline btn-sm w-fit" on:click={() => addSkill('learning')}>
                                + Add Skill
                            </button>
                        </div>
                        <button class="btn btn-primary" on:click={saveProfile}>Save Changes</button>
                    </div>
                </div>
            </div>
        {:else}
            <!-- Profile Info -->
            <div class="grid md:grid-cols-2 gap-6 mb-6">
                <div class="card bg-base-100 shadow-xl">
                    <div class="card-body">
                        <h2 class="card-title">About</h2>
                        <p class="text-gray-600">{profile.bio || 'No bio yet.'}</p>
                        {#if profile.location}
                            <p class="text-sm text-gray-500 mt-2">📍 {profile.location}</p>
                        {/if}
                    </div>
                </div>

                <div class="card bg-base-100 shadow-xl">
                    <div class="card-body">
                        <h2 class="card-title">Skills</h2>
                        <div class="mb-4">
                            <h3 class="text-sm font-semibold text-primary mb-2">Teaching</h3>
                            <div class="flex flex-wrap gap-2">
                                {#each profile.skills_teaching || [] as skill}
                                    <span class="badge badge-primary">{skill}</span>
                                {:else}
                                    <span class="text-gray-400 text-sm">No skills listed yet</span>
                                {/each}
                            </div>
                        </div>
                        <div>
                            <h3 class="text-sm font-semibold text-secondary mb-2">Learning</h3>
                            <div class="flex flex-wrap gap-2">
                                {#each profile.skills_learning || [] as skill}
                                    <span class="badge badge-secondary">{skill}</span>
                                {:else}
                                    <span class="text-gray-400 text-sm">No skills listed yet</span>
                                {/each}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        {/if}

        <!-- Reviews -->
        <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
                <h2 class="card-title mb-4">Reviews ({reviews.length})</h2>
                {#if reviews.length === 0}
                    <p class="text-gray-500">No reviews yet.</p>
                {:else}
                    <div class="space-y-4">
                        {#each reviews as review}
                            <div class="border-b border-base-200 pb-4 last:border-0">
                                <div class="flex justify-between items-start">
                                    <div class="flex items-center gap-2">
                                        <div class="avatar">
                                            <div class="w-8 rounded-full">
                                                <img src={review.reviewer?.avatar_url || '/default-avatar.png'} alt="" />
                                            </div>
                                        </div>
                                        <span class="font-semibold">{review.reviewer?.display_name || review.reviewer?.username}</span>
                                    </div>
                                    <div class="flex items-center gap-1">
                                        {#each Array(5) as _, i}
                                            <span class="text-sm {i < review.rating ? 'text-yellow-500' : 'text-gray-300'}">★</span>
                                        {/each}
                                    </div>
                                </div>
                                <p class="mt-2 text-gray-600">{review.comment || 'No comment'}</p>
                                <p class="text-xs text-gray-400 mt-1">{new Date(review.created_at).toLocaleDateString()}</p>
                            </div>
                        {/each}
                    </div>
                {/if}
            </div>
        </div>
    </div>
{/if}
