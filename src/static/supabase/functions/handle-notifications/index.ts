import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    const { session_id, action } = await req.json()

    // Get session details
    const { data: session } = await supabaseClient
      .from('sessions')
      .select('*, teacher:teacher_id(*), learner:learner_id(*)')
      .eq('id', session_id)
      .single()

    if (!session) throw new Error('Session not found')

    const notifications = []

    if (action === 'session_requested') {
      notifications.push({
        user_id: session.teacher_id,
        type: 'session_request',
        title: 'New Session Request',
        message: `${session.learner.display_name} wants to learn ${session.skill_taught} from you!`,
        data: { session_id, skill: session.skill_taught }
      })
    } else if (action === 'session_accepted') {
      notifications.push({
        user_id: session.learner_id,
        type: 'session_accepted',
        title: 'Session Accepted!',
        message: `${session.teacher.display_name} accepted your session request.`,
        data: { session_id }
      })
    } else if (action === 'session_completed') {
      notifications.push(
        {
          user_id: session.teacher_id,
          type: 'session_completed',
          title: 'Session Completed',
          message: `Your session with ${session.learner.display_name} is complete. You earned ${session.credits_cost} credits!`,
          data: { session_id, credits_earned: session.credits_cost }
        },
        {
          user_id: session.learner_id,
          type: 'session_completed',
          title: 'Session Completed',
          message: `Your session with ${session.teacher.display_name} is complete. Please leave a review!`,
          data: { session_id }
        }
      )
    }

    if (notifications.length > 0) {
      await supabaseClient.from('notifications').insert(notifications)
    }

    return new Response(
      JSON.stringify({ success: true, notifications_sent: notifications.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
