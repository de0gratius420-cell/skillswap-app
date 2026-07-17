import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    const { data: { user } } = await supabase.auth.getUser(req.headers.get('authorization')?.replace('Bearer ', '') ?? '')
    if (!user) throw new Error('Not authenticated')

    const { action, session_id, reason, description, evidence } = await req.json()

    if (action === 'open') {
      // Get session details
      const { data: session } = await supabase.from('sessions').select('*').eq('id', session_id).single()
      if (!session) throw new Error('Session not found')
      if (session.status !== 'completed') throw new Error('Can only dispute completed sessions')

      // Check dispute window
      const { data: config } = await supabase.from('platform_config').select('dispute_window_hours').single()
      const sessionAge = (Date.now() - new Date(session.updated_at).getTime()) / (1000 * 60 * 60)
      if (sessionAge > config.dispute_window_hours) throw new Error(`Dispute window closed (${config.dispute_window_hours}h)`)

      // Determine respondent
      const respondent_id = session.teacher_id === user.id ? session.learner_id : session.teacher_id

      const { data: dispute, error } = await supabase.from('disputes').insert({
        session_id,
        opened_by: user.id,
        respondent_id,
        reason,
        description,
        evidence: evidence || []
      }).select().single()

      if (error) throw error

      // Notify both parties
      await supabase.from('notifications').insert([
        { user_id: respondent_id, type: 'dispute_opened', title: 'Dispute Opened', message: `A dispute has been opened for session #${session_id.substring(0, 8)}`, data: { dispute_id: dispute.id } },
        { user_id: user.id, type: 'dispute_opened', title: 'Dispute Submitted', message: 'Your dispute has been submitted for review', data: { dispute_id: dispute.id } }
      ])

      return new Response(JSON.stringify({ success: true, dispute }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    if (action === 'list') {
      const { data: disputes } = await supabase.from('disputes').select('*, session:sessions(*), opener:profiles!disputes_opened_by_fkey(*), respondent:profiles!disputes_respondent_id_fkey(*)')
        .or(`opened_by.eq.${user.id},respondent_id.eq.${user.id}`)
        .order('created_at', { ascending: false })
      return new Response(JSON.stringify({ disputes }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
