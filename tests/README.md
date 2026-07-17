# SkillSwap - Peer-to-Peer Skill Exchange Platform

A complete production-ready platform where users teach skills to earn credits, and spend credits to learn new skills.

## 🚀 Features

- **Skill Exchange**: Teach what you know, learn what you don't
- **Credit Economy**: Platform currency with purchase, earning, and withdrawal
- **Real-time Video**: WebRTC-powered video sessions with chat
- **Stripe Payments**: Buy credits and subscriptions
- **Subscription Plans**: Free, Pro, Teacher Pro, Enterprise tiers
- **Admin Dashboard**: Full platform management with revenue analytics
- **Dispute System**: Handle conflicts with admin resolution
- **Payout System**: Teachers withdraw earnings to PayPal/Bank/Crypto
- **Platform Fees**: Configurable commission on each session
- **Featured Listings**: Promote your teaching profile
- **Audit Logging**: Complete transparency and compliance

## 💰 Monetization Model

| Revenue Stream | Implementation |
|---------------|----------------|
| **Platform Fee** | 20% commission on each session (configurable) |
| **Credit Purchases** | Users buy credits with real money via Stripe |
| **Subscriptions** | Monthly plans with credits included + reduced fees |
| **Featured Listings** | Pay credits to boost profile visibility |
| **Verification** | Paid teacher verification badge |

## 🛠️ Setup

### 1. Supabase Setup
```bash
# Create new Supabase project
# Run migrations in order:
# 1. 001_complete_schema.sql
# 2. 002_monetization_schema.sql
```

### 2. Stripe Setup
```bash
# Create Stripe account
# Set up products for credit packages and subscription plans
# Add price IDs to database
# Configure webhook endpoint: https://your-project.supabase.co/functions/v1/stripe-webhook
```

### 3. Environment Variables
```bash
cp .env.example .env
# Fill in your Supabase and Stripe credentials
```

### 4. Install & Run
```bash
npm install
npm run dev
```

### 5. Deploy Edge Functions
```bash
supabase functions deploy stripe-checkout
supabase functions deploy stripe-webhook
supabase functions deploy payouts
supabase functions deploy disputes
supabase functions deploy handle-notifications
```

## 📁 Project Structure

```
skillswap-app/
├── supabase/
│   ├── migrations/
│   │   ├── 001_complete_schema.sql
│   │   └── 002_monetization_schema.sql
│   └── functions/
│       ├── stripe-checkout/
│       ├── stripe-webhook/
│       ├── payouts/
│       ├── disputes/
│       └── handle-notifications/
├── src/
│   ├── lib/
│   │   ├── supabase.ts
│   │   └── database.types.ts
│   ├── stores/
│   │   └── index.ts
│   ├── components/
│   │   ├── Header.svelte
│   │   ├── TeacherCard.svelte
│   │   └── SessionCard.svelte
│   ├── routes/
│   │   ├── +page.svelte (Home)
│   │   ├── login/+page.svelte
│   │   ├── discover/+page.svelte
│   │   ├── sessions/+page.svelte
│   │   ├── profile/[username]/+page.svelte
│   │   ├── credits/+page.svelte
│   │   ├── subscription/+page.svelte
│   │   ├── payouts/+page.svelte
│   │   ├── admin/+page.svelte
│   │   └── session/[id]/call/+page.svelte
│   └── types/
│       └── index.ts
└── package.json
```

## 🎯 Revenue Projections

With 1,000 active users:
- Average 2 sessions/user/month at 5 credits each = 10,000 credits exchanged
- 20% platform fee = 2,000 credits in fees
- If 50% of fees are cashed out at $0.50/credit = $500/month from fees
- Plus credit purchases, subscriptions, featured listings = $2,000-5,000/month potential

## 🔒 Security

- Row Level Security (RLS) on all tables
- Audit logging for all critical operations
- Admin-only access to sensitive data
- Stripe webhook signature verification
- Dispute resolution system

## 📄 License

MIT License - Built for earning and learning! 🚀
