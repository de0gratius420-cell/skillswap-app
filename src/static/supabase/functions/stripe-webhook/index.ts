import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@12.0.0'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', { apiVersion: '2023-10-16' })
const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? ''

serve(async (req) => {
  const signature = req.headers.get('stripe-signature')
  if (!signature) return new Response('No signature', { status: 400 })

  const body = await req.text()
  let event

  try {
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret)
  } catch (err) {
    return new Response(`Webhook Error: ${err.message}`, { status: 400 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { persistSession: false } }
  )

  // Log the event
  await supabase.from('stripe_events').insert({
    stripe_event_id: event.id,
    event_type: event.type,
    event_data: event
  })

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object
        const { type, user_id, package_id, plan_id, credits } = session.metadata

        if (type === 'credits') {
          // Add credits to user
          const { data: profile } = await supabase.from('profiles').select('credits').eq('id', user_id).single()
          const newBalance = (profile?.credits || 0) + parseInt(credits)

          await supabase.from('profiles').update({ credits: newBalance }).eq('id', user_id)
          await supabase.from('credit_transactions').insert({
            user_id,
            amount: parseInt(credits),
            type: 'purchase',
            description: `Purchased ${credits} credits via Stripe`,
            balance_after: newBalance
          })
        } 
        else if (type === 'subscription') {
          // Create subscription record
          await supabase.from('user_subscriptions').insert({
            user_id,
            plan_id,
            stripe_subscription_id: session.subscription,
            stripe_customer_id: session.customer,
            status: 'active',
            current_period_start: new Date().toISOString(),
            current_period_end: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
          })

          // Add subscription bonus credits
          const { data: plan } = await supabase.from('subscription_plans').select('credits_included_monthly').eq('id', plan_id).single()
          if (plan?.credits_included_monthly) {
            const { data: profile } = await supabase.from('profiles').select('credits').eq('id', user_id).single()
            await supabase.from('profiles').update({ 
              credits: (profile?.credits || 0) + plan.credits_included_monthly 
            }).eq('id', user_id)
          }
        }
        break
      }

      case 'invoice.payment_succeeded': {
        const invoice = event.data.object
        if (invoice.subscription) {
          // Renew subscription credits
          const { data: sub } = await supabase.from('user_subscriptions')
            .select('*, plan:subscription_plans(*)').eq('stripe_subscription_id', invoice.subscription).single()

          if (sub?.plan?.credits_included_monthly) {
            const { data: profile } = await supabase.from('profiles').select('credits').eq('id', sub.user_id).single()
            await supabase.from('profiles').update({ 
              credits: (profile?.credits || 0) + sub.plan.credits_included_monthly 
            }).eq('id', sub.user_id)

            await supabase.from('credit_transactions').insert({
              user_id: sub.user_id,
              amount: sub.plan.credits_included_monthly,
              type: 'bonus',
              description: `Monthly subscription credits - ${sub.plan.name}`,
              balance_after: (profile?.credits || 0) + sub.plan.credits_included_monthly
            })
          }
        }
        break
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object
        await supabase.from('user_subscriptions')
          .update({ status: 'cancelled', cancel_at_period_end: true })
          .eq('stripe_subscription_id', subscription.id)
        break
      }
    }

    // Mark as processed
    await supabase.from('stripe_events').update({ processed: true, processed_at: new Date().toISOString() }).eq('stripe_event_id', event.id)

  } catch (err) {
    await supabase.from('stripe_events').update({ error_message: err.message }).eq('stripe_event_id', event.id)
    return new Response(`Error: ${err.message}`, { status: 500 })
  }

  return new Response(JSON.stringify({ received: true }), { headers: { 'Content-Type': 'application/json' } })
})
