<script lang="ts">
    import { user, notifications, toast } from '../stores'
    import { supabase } from '../lib/supabase'
    import { goto } from '$app/navigation'

    let mobileMenuOpen = false

    async function handleLogout() {
        await supabase.auth.signOut()
        user.clear()
        toast.add('Logged out successfully', 'success')
        goto('/')
    }

    $: unreadCount = $notifications.filter(n => !n.is_read).length
</script>

<header class="navbar bg-base-100 shadow-lg sticky top-0 z-50">
    <div class="navbar-start">
        <a href="/" class="btn btn-ghost text-xl">
            <span class="text-primary font-bold">Skill</span><span class="font-bold">Swap</span>
        </a>
    </div>

    <div class="navbar-center hidden lg:flex">
        <ul class="menu menu-horizontal px-1 gap-2">
            <li><a href="/discover">Discover</a></li>
            <li><a href="/sessions">My Sessions</a></li>
            <li><a href="/messages">Messages</a></li>
        </ul>
    </div>

    <div class="navbar-end gap-2">
        {#if $user}
            <div class="dropdown dropdown-end">
                <button class="btn btn-ghost btn-circle" tabindex="0">
                    <div class="indicator">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                        </svg>
                        {#if unreadCount > 0}
                            <span class="badge badge-sm badge-primary indicator-item">{unreadCount}</span>
                        {/if}
                    </div>
                </button>
                <ul class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-80 mt-4">
                    {#if $notifications.length === 0}
                        <li><span class="text-sm text-gray-500">No notifications</span></li>
                    {:else}
                        {#each $notifications.slice(0, 5) as notification}
                            <li class="{notification.is_read ? 'opacity-60' : ''}">
                                <a href="/sessions" class="flex flex-col items-start">
                                    <span class="font-semibold text-sm">{notification.title}</span>
                                    <span class="text-xs text-gray-500">{notification.message}</span>
                                </a>
                            </li>
                        {/each}
                    {/if}
                </ul>
            </div>

            <div class="dropdown dropdown-end">
                <button class="btn btn-ghost btn-circle avatar" tabindex="0">
                    <div class="w-10 rounded-full">
                        <img src={$user.avatar_url || '/default-avatar.png'} alt={$user.display_name || $user.username} />
                    </div>
                </button>
                <ul class="dropdown-content menu p-2 shadow bg-base-100 rounded-box w-52 mt-4">
                    <li class="menu-title">
                        <span>{$user.display_name || $user.username}</span>
                        <span class="text-xs text-primary">{$user.credits} credits</span>
                    </li>
                    <li><a href="/profile">Profile</a></li>
                    <li><a href="/settings">Settings</a></li>
                    <div class="divider my-1"></div>
                    <li><button on:click={handleLogout}>Logout</button></li>
                </ul>
            </div>
        {:else}
            <a href="/login" class="btn btn-primary btn-sm">Get Started</a>
        {/if}

        <button class="btn btn-ghost lg:hidden" on:click={() => mobileMenuOpen = !mobileMenuOpen}>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
        </button>
    </div>
</header>

{#if mobileMenuOpen}
    <div class="lg:hidden bg-base-100 shadow-lg p-4">
        <ul class="menu menu-vertical">
            <li><a href="/discover">Discover</a></li>
            <li><a href="/sessions">My Sessions</a></li>
            <li><a href="/messages">Messages</a></li>
            {#if $user}
                <li><a href="/profile">Profile</a></li>
                <li><button on:click={handleLogout}>Logout</button></li>
            {:else}
                <li><a href="/login">Login</a></li>
            {/if}
        </ul>
    </div>
{/if}
