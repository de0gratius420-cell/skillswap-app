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

    const { action, credits_amount, method, payout_email } = await req.json()

    if (action === 'request') {
      // Get platform config
      const { data: config } = await supabase.from('platform_config').select('*').single()
      const { data: profile } = await supabase.from('profiles').select('credits').eq('id', user.id).single()

      if (!profile) throw new Error('Profile not found')
      if (credits_amount < config.min_withdrawal_credits) throw new Error(`Minimum withdrawal is ${config.min_withdrawal_credits} credits`)
      if (profile.credits < credits_amount) throw new Error('Insufficient credits')

      const usd_amount = credits_amount * config.credit_to_usd_rate
      const platform_fee = usd_amount * (config.platform_fee_percent / 100)
      const net_amount = usd_amount - platform_fee

      // Create payout record
      const { data: payout, error } = await supabase.from('payouts').insert({
        user_id: user.id,
        credits_amount,
        usd_amount,
        platform_fee_deducted: platform_fee,
        net_amount,
        method,
        payout_email,
        status: 'pending'
      }).select().single()

      if (error) throw error

      // Deduct credits immediately
      await supabase.from('profiles').update({ credits: profile.credits - credits_amount }).eq('id', user.id)
      await supabase.from('credit_transactions').insert({
        user_id: user.id,
        amount: -credits_amount,
        type: 'penalty',
        description: `Payout request #${payout.id.substring(0, 8)} - ${credits_amount} credits`,
        balance_after: profile.credits - credits_amount
      })

      return new Response(
        JSON.stringify({ success: true, payout, message: `Payout request created. You'll receive $${net_amount.toFixed(2)} (after ${config.platform_fee_percent}% fee)` }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (action === 'list') {
      const { data: payouts } = await supabase.from('payouts').select('*').eq('user_id', user.id).order('created_at', { ascending: false })
      return new Response(JSON.stringify({ payouts }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
