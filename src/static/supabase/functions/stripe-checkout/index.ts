import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@12.0.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', { apiVersion: '2023-10-16' })

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

    const { type, package_id, plan_id, success_url, cancel_url } = await req.json()

    // Get or create Stripe customer
    let { data: existingCustomer } = await supabase
      .from('user_subscriptions')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .single()

    let customerId = existingCustomer?.stripe_customer_id

    if (!customerId) {
      const { data: profile } = await supabase.from('profiles').select('username, display_name').eq('id', user.id).single()
      const customer = await stripe.customers.create({
        email: user.email,
        name: profile?.display_name || profile?.username,
        metadata: { supabase_user_id: user.id }
      })
      customerId = customer.id
    }

    let session

    if (type === 'credits') {
      // Buy credits one-time payment
      const { data: pkg } = await supabase.from('credit_packages').select('*').eq('id', package_id).single()
      if (!pkg) throw new Error('Package not found')

      session = await stripe.checkout.sessions.create({
        customer: customerId,
        payment_method_types: ['card'],
        line_items: [{
          price_data: {
            currency: 'usd',
            product_data: { name: pkg.name, description: pkg.description || `${pkg.credits} credits` },
            unit_amount: Math.round(pkg.price_usd * 100),
          },
          quantity: 1,
        }],
        mode: 'payment',
        success_url: `${success_url}?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${cancel_url}?canceled=true`,
        metadata: { type: 'credits', user_id: user.id, package_id, credits: pkg.credits + (pkg.bonus_credits || 0) }
      })

    } else if (type === 'subscription') {
      // Subscribe to plan
      const { data: plan } = await supabase.from('subscription_plans').select('*').eq('id', plan_id).single()
      if (!plan) throw new Error('Plan not found')
      if (!plan.stripe_price_id_monthly) throw new Error('Plan not configured for Stripe')

      session = await stripe.checkout.sessions.create({
        customer: customerId,
        payment_method_types: ['card'],
        line_items: [{ price: plan.stripe_price_id_monthly, quantity: 1 }],
        mode: 'subscription',
        success_url: `${success_url}?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${cancel_url}?canceled=true`,
        metadata: { type: 'subscription', user_id: user.id, plan_id }
      })
    }

    return new Response(
      JSON.stringify({ sessionId: session.id, url: session.url }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
