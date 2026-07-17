<script lang="ts">
    import { onMount, onDestroy } from 'svelte'
    import { page } from '$app/stores'
    import { supabase, getSessionMessages, sendMessage, subscribeToMessages } from '../../lib/supabase'
    import { user, toast } from '../../stores'
    import { goto } from '$app/navigation'

    let sessionId = $page.params.id
    let session: any = null
    let localStream: MediaStream | null = null
    let remoteStream: MediaStream | null = null
    let peerConnection: RTCPeerConnection | null = null
    let dataChannel: RTCDataChannel | null = null
    let messages: any[] = []
    let newMessage = ''
    let chatOpen = true
    let isTeacher = false
    let connectionStatus = 'connecting' // connecting, connected, disconnected
    let timer = 0
    let timerInterval: any
    let videoEnabled = true
    let audioEnabled = true

    const servers = {
        iceServers: [
            { urls: 'stun:stun.l.google.com:19302' },
            { urls: 'stun:stun1.l.google.com:19302' }
        ]
    }

    onMount(async () => {
        await loadSession()
        await startLocalVideo()
        await setupWebRTC()
        await loadMessages()

        // Start session timer
        timerInterval = setInterval(() => timer++, 1000)
    })

    onDestroy(() => {
        if (timerInterval) clearInterval(timerInterval)
        if (localStream) localStream.getTracks().forEach(t => t.stop())
        if (peerConnection) peerConnection.close()
    })

    async function loadSession() {
        const { data } = await supabase.from('sessions').select('*, teacher:teacher_id(*), learner:learner_id(*)').eq('id', sessionId).single()
        if (data) {
            session = data
            isTeacher = data.teacher_id === $user?.id
        }
    }

    async function startLocalVideo() {
        try {
            localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true })
            const localVideo = document.getElementById('localVideo') as HTMLVideoElement
            if (localVideo) localVideo.srcObject = localStream
        } catch (e) {
            toast.add('Camera access denied. Check permissions.', 'error')
        }
    }

    async function setupWebRTC() {
        peerConnection = new RTCPeerConnection(servers)

        // Add local tracks
        localStream?.getTracks().forEach(track => {
            peerConnection?.addTrack(track, localStream!)
        })

        // Handle remote stream
        peerConnection.ontrack = (event) => {
            remoteStream = event.streams[0]
            const remoteVideo = document.getElementById('remoteVideo') as HTMLVideoElement
            if (remoteVideo) remoteVideo.srcObject = remoteStream
            connectionStatus = 'connected'
        }

        // ICE candidate handling
        peerConnection.onicecandidate = async (event) => {
            if (event.candidate) {
                await supabase.from('webrtc_signals').insert({
                    session_id: sessionId,
                    sender_id: $user?.id,
                    signal: { type: 'ice', candidate: event.candidate.toJSON() }
                })
            }
        }

        // Create data channel for chat
        dataChannel = peerConnection.createDataChannel('chat')
        dataChannel.onmessage = (event) => {
            const msg = JSON.parse(event.data)
            messages = [...messages, msg]
        }

        // Listen for signals
        const channel = supabase.channel(`webrtc-${sessionId}`)
        channel.on('postgres_changes', 
            { event: 'INSERT', schema: 'public', table: 'webrtc_signals', filter: `session_id=eq.${sessionId}` },
            async (payload) => {
                const signal = payload.new.signal
                if (signal.type === 'offer') {
                    await peerConnection?.setRemoteDescription(new RTCSessionDescription(signal.offer))
                    const answer = await peerConnection?.createAnswer()
                    await peerConnection?.setLocalDescription(answer)
                    await supabase.from('webrtc_signals').insert({
                        session_id: sessionId,
                        sender_id: $user?.id,
                        signal: { type: 'answer', answer }
                    })
                } else if (signal.type === 'answer') {
                    await peerConnection?.setRemoteDescription(new RTCSessionDescription(signal.answer))
                } else if (signal.type === 'ice') {
                    await peerConnection?.addIceCandidate(new RTCIceCandidate(signal.candidate))
                }
            }
        ).subscribe()

        // Initiator creates offer
        if (isTeacher) {
            const offer = await peerConnection.createOffer()
            await peerConnection.setLocalDescription(offer)
            await supabase.from('webrtc_signals').insert({
                session_id: sessionId,
                sender_id: $user?.id,
                signal: { type: 'offer', offer }
            })
        }
    }

    async function loadMessages() {
        messages = await getSessionMessages(sessionId)
    }

    async function sendChatMessage() {
        if (!newMessage.trim()) return

        const msg = await sendMessage(sessionId, newMessage)
        if (msg) {
            messages = [...messages, msg]
            newMessage = ''
            // Also send via WebRTC data channel if connected
            if (dataChannel?.readyState === 'open') {
                dataChannel.send(JSON.stringify(msg))
            }
        }
    }

    async function endSession() {
        if (confirm('End this session? This will mark it as completed.')) {
            await supabase.from('sessions').update({ status: 'completed' }).eq('id', sessionId)
            toast.add('Session ended. Credits have been transferred.', 'success')
            goto('/sessions')
        }
    }

    async function toggleVideo() {
        videoEnabled = !videoEnabled
        localStream?.getVideoTracks().forEach(t => t.enabled = videoEnabled)
    }

    async function toggleAudio() {
        audioEnabled = !audioEnabled
        localStream?.getAudioTracks().forEach(t => t.enabled = audioEnabled)
    }

    function formatTime(seconds: number) {
        const mins = Math.floor(seconds / 60)
        const secs = seconds % 60
        return `${mins}:${secs.toString().padStart(2, '0')}`
    }
</script>

<svelte:head>
    <title>Video Session - SkillSwap</title>
</svelte:head>

<div class="h-screen flex flex-col bg-base-300">
    <!-- Top Bar -->
    <div class="bg-base-100 px-4 py-2 flex justify-between items-center shadow-lg z-10">
        <div class="flex items-center gap-4">
            <h2 class="font-bold">{session?.skill_taught || 'Session'}</h2>
            <span class="badge {connectionStatus === 'connected' ? 'badge-success' : 'badge-warning'}">
                {connectionStatus === 'connected' ? '● Connected' : '○ Connecting...'}
            </span>
            <span class="font-mono text-lg">{formatTime(timer)}</span>
        </div>
        <div class="flex gap-2">
            <button class="btn btn-sm btn-circle {chatOpen ? 'btn-primary' : 'btn-ghost'}" on:click={() => chatOpen = !chatOpen}>
                💬
            </button>
            <button class="btn btn-sm btn-error" on:click={endSession}>End Session</button>
        </div>
    </div>

    <!-- Main Content -->
    <div class="flex-1 flex overflow-hidden">
        <!-- Video Area -->
        <div class="flex-1 relative bg-base-300">
            <!-- Remote Video (main) -->
            <video id="remoteVideo" autoplay playsinline class="w-full h-full object-cover"></video>

            <!-- Local Video (pip) -->
            <div class="absolute bottom-4 right-4 w-48 h-36 rounded-xl overflow-hidden shadow-lg border-2 border-base-100">
                <video id="localVideo" autoplay playsinline muted class="w-full h-full object-cover {videoEnabled ? '' : 'opacity-50'}"></video>
                {#if !videoEnabled}
                    <div class="absolute inset-0 flex items-center justify-center bg-black/50">
                        <span class="text-2xl">🚫</span>
                    </div>
                {/if}
            </div>

            <!-- Controls -->
            <div class="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-3">
                <button class="btn btn-circle btn-lg {audioEnabled ? 'btn-primary' : 'btn-error'}" on:click={toggleAudio}>
                    {audioEnabled ? '🎤' : '🎤❌'}
                </button>
                <button class="btn btn-circle btn-lg {videoEnabled ? 'btn-primary' : 'btn-error'}" on:click={toggleVideo}>
                    {videoEnabled ? '📹' : '📹❌'}
                </button>
                <button class="btn btn-circle btn-lg btn-error" on:click={endSession}>📞</button>
            </div>
        </div>

        <!-- Chat Sidebar -->
        {#if chatOpen}
            <div class="w-80 bg-base-100 flex flex-col border-l border-base-300">
                <div class="p-3 border-b border-base-300 font-semibold">Session Chat</div>
                <div class="flex-1 overflow-y-auto p-3 space-y-2">
                    {#each messages as msg}
                        <div class="chat {msg.sender_id === $user?.id ? 'chat-end' : 'chat-start'}">
                            <div class="chat-header text-xs">
                                {msg.sender?.display_name || msg.sender?.username}
                            </div>
                            <div class="chat-bubble {msg.sender_id === $user?.id ? 'chat-bubble-primary' : 'chat-bubble-ghost'}">
                                {msg.content}
                            </div>
                            <div class="chat-footer text-xs opacity-50">
                                {new Date(msg.created_at).toLocaleTimeString()}
                            </div>
                        </div>
                    {/each}
                </div>
                <div class="p-3 border-t border-base-300">
                    <div class="join w-full">
                        <input type="text" class="input input-bordered join-item flex-1" 
                               placeholder="Type a message..." bind:value={newMessage}
                               on:keypress={(e) => e.key === 'Enter' && sendChatMessage()} />
                        <button class="btn btn-primary join-item" on:click={sendChatMessage}>Send</button>
                    </div>
                </div>
            </div>
        {/if}
    </div>
</div>

<style>
    :global(body) { overflow: hidden; }
</style>
