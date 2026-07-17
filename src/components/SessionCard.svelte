<script lang="ts">
    import type { Session } from '../types'
    import { updateSessionStatus, supabase } from '../lib/supabase'
    import { toast } from '../stores'
    import { goto } from '$app/navigation'

    export let session: Session
    export let isTeacher: boolean

    const statusColors = {
        pending: 'badge-warning',
        accepted: 'badge-info',
        scheduled: 'badge-primary',
        in_progress: 'badge-secondary',
        completed: 'badge-success',
        cancelled: 'badge-error',
        disputed: 'badge-error'
    }

    async function acceptSession() {
        try {
            await updateSessionStatus(session.id, 'accepted')
            toast.add('Session accepted!', 'success')
        } catch (e) {
            toast.add('Failed to accept session', 'error')
        }
    }

    async function cancelSession() {
        try {
            await updateSessionStatus(session.id, 'cancelled', { 
                cancelled_by: (await supabase.auth.getUser()).data.user?.id 
            })
            toast.add('Session cancelled', 'info')
        } catch (e) {
            toast.add('Failed to cancel', 'error')
        }
    }

    async function completeSession() {
        try {
            await updateSessionStatus(session.id, 'completed')
            toast.add('Session completed! Credits transferred.', 'success')
        } catch (e) {
            toast.add('Failed to complete session', 'error')
        }
    }
</script>

<div class="card bg-base-100 shadow-md hover:shadow-lg transition-shadow">
    <div class="card-body">
        <div class="flex justify-between items-start">
            <div class="flex items-center gap-3">
                <div class="avatar">
                    <div class="w-12 rounded-full">
                        <img src={isTeacher ? session.learner?.avatar_url : session.teacher?.avatar_url} alt="avatar" />
                    </div>
                </div>
                <div>
                    <h3 class="font-bold">
                        {isTeacher ? 'Teaching' : 'Learning'}: {session.skill_taught}
                    </h3>
                    <p class="text-sm text-gray-500">
                        with {isTeacher ? session.learner?.display_name : session.teacher?.display_name}
                    </p>
                </div>
            </div>
            <span class="badge {statusColors[session.status]}">{session.status}</span>
        </div>

        <div class="mt-3 space-y-1 text-sm">
            <p><span class="font-semibold">Format:</span> {session.format}</p>
            <p><span class="font-semibold">Duration:</span> {session.duration_minutes} min</p>
            <p><span class="font-semibold">Credits:</span> {session.credits_cost}</p>
            {#if session.scheduled_at}
                <p><span class="font-semibold">Scheduled:</span> {new Date(session.scheduled_at).toLocaleString()}</p>
            {/if}
        </div>

        <div class="card-actions justify-end gap-2 mt-4">
            <button class="btn btn-ghost btn-sm" on:click={() => goto(`/session/${session.id}`)}>
                Details
            </button>

            {#if session.status === 'pending' && isTeacher}
                <button class="btn btn-success btn-sm" on:click={acceptSession}>Accept</button>
                <button class="btn btn-error btn-sm" on:click={cancelSession}>Decline</button>
            {/if}

            {#if session.status === 'scheduled'}
                <button class="btn btn-primary btn-sm" on:click={() => goto(`/session/${session.id}/call`)}>
                    Join
                </button>
            {/if}

            {#if session.status === 'in_progress'}
                <button class="btn btn-success btn-sm" on:click={completeSession}>Complete</button>
            {/if}

            {#if session.status === 'completed'}
                <button class="btn btn-primary btn-sm" on:click={() => goto(`/session/${session.id}/review`)}>
                    Leave Review
                </button>
            {/if}
        </div>
    </div>
</div>
