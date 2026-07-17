<script lang="ts">
    import { supabase } from '../lib/supabase'
    import { user, toast } from '../stores'
    import { goto } from '$app/navigation'

    let email = ''
    let password = ''
    let isSignUp = false
    let username = ''
    let displayName = ''
    let loading = false

    async function handleSubmit() {
        loading = true
        try {
            if (isSignUp) {
                const { data, error } = await supabase.auth.signUp({
                    email,
                    password,
                    options: {
                        data: { username, full_name: displayName }
                    }
                })
                if (error) throw error
                toast.add('Check your email to confirm your account!', 'success')
            } else {
                const { data, error } = await supabase.auth.signInWithPassword({
                    email,
                    password
                })
                if (error) throw error
                await user.refresh()
                toast.add('Welcome back!', 'success')
                goto('/')
            }
        } catch (e: any) {
            toast.add(e.message, 'error')
        } finally {
            loading = false
        }
    }

    async function handleOAuth(provider: 'google' | 'github') {
        const { error } = await supabase.auth.signInWithOAuth({ provider })
        if (error) toast.add(error.message, 'error')
    }
</script>

<svelte:head>
    <title>{isSignUp ? 'Sign Up' : 'Login'} - SkillSwap</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center px-4 bg-base-200">
    <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body">
            <h2 class="card-title text-2xl justify-center mb-2">
                {isSignUp ? 'Create Account' : 'Welcome Back'}
            </h2>
            <p class="text-center text-gray-500 mb-6">
                {isSignUp ? 'Start your learning journey' : 'Sign in to continue'}
            </p>

            <form on:submit|preventDefault={handleSubmit} class="space-y-4">
                {#if isSignUp}
                    <div class="form-control">
                        <label class="label"><span class="label-text">Username</span></label>
                        <input type="text" class="input input-bordered" bind:value={username} required />
                    </div>
                    <div class="form-control">
                        <label class="label"><span class="label-text">Display Name</span></label>
                        <input type="text" class="input input-bordered" bind:value={displayName} />
                    </div>
                {/if}

                <div class="form-control">
                    <label class="label"><span class="label-text">Email</span></label>
                    <input type="email" class="input input-bordered" bind:value={email} required />
                </div>

                <div class="form-control">
                    <label class="label"><span class="label-text">Password</span></label>
                    <input type="password" class="input input-bordered" bind:value={password} required minlength="6" />
                </div>

                <button type="submit" class="btn btn-primary w-full" disabled={loading}>
                    {loading ? 'Loading...' : isSignUp ? 'Create Account' : 'Sign In'}
                </button>
            </form>

            <div class="divider">or</div>

            <div class="space-y-2">
                <button class="btn btn-outline w-full" on:click={() => handleOAuth('google')}>
                    Continue with Google
                </button>
                <button class="btn btn-outline w-full" on:click={() => handleOAuth('github')}>
                    Continue with GitHub
                </button>
            </div>

            <p class="text-center mt-4">
                {isSignUp ? 'Already have an account?' : "Don't have an account?"}
                <button class="link link-primary" on:click={() => isSignUp = !isSignUp}>
                    {isSignUp ? 'Sign In' : 'Sign Up'}
                </button>
            </p>

            {#if isSignUp}
                <p class="text-xs text-center text-gray-500 mt-2">
                    By signing up, you agree to our Terms and get 10 free starter credits.
                </p>
            {/if}
        </div>
    </div>
</div>
