export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          username: string;
          display_name: string | null;
          avatar_url: string | null;
          bio: string | null;
          location: string | null;
          skills_teaching: string[];
          skills_learning: string[];
          credits: number;
          rating_average: number;
          total_sessions_taught: number;
          total_sessions_learned: number;
          total_reviews_received: number;
          is_verified: boolean;
          is_active: boolean;
          timezone: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          username: string;
          display_name?: string | null;
          avatar_url?: string | null;
          bio?: string | null;
          location?: string | null;
          skills_teaching?: string[];
          skills_learning?: string[];
          credits?: number;
          rating_average?: number;
          total_sessions_taught?: number;
          total_sessions_learned?: number;
          total_reviews_received?: number;
          is_verified?: boolean;
          is_active?: boolean;
          timezone?: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          username?: string;
          display_name?: string | null;
          avatar_url?: string | null;
          bio?: string | null;
          location?: string | null;
          skills_teaching?: string[];
          skills_learning?: string[];
          credits?: number;
          rating_average?: number;
          total_sessions_taught?: number;
          total_sessions_learned?: number;
          total_reviews_received?: number;
          is_verified?: boolean;
          is_active?: boolean;
          timezone?: string;
          created_at?: string;
          updated_at?: string;
        };
      };
      sessions: {
        Row: {
          id: string;
          teacher_id: string;
          learner_id: string;
          skill_taught: string;
          skill_learned: string;
          status: 'pending' | 'accepted' | 'scheduled' | 'in_progress' | 'completed' | 'cancelled' | 'disputed';
          format: 'video' | 'chat' | 'in_person';
          scheduled_at: string | null;
          duration_minutes: number;
          credits_cost: number;
          teacher_notes: string | null;
          learner_notes: string | null;
          meeting_link: string | null;
          created_at: string;
          updated_at: string;
        };
      };
      reviews: {
        Row: {
          id: string;
          session_id: string;
          reviewer_id: string;
          reviewee_id: string;
          rating: number;
          comment: string | null;
          is_teacher_review: boolean;
          helpful_count: number;
          created_at: string;
        };
      };
      credit_transactions: {
        Row: {
          id: string;
          user_id: string;
          amount: number;
          type: 'earn' | 'spend' | 'purchase' | 'bonus' | 'refund' | 'penalty';
          description: string | null;
          session_id: string | null;
          balance_after: number;
          created_at: string;
        };
      };
      messages: {
        Row: {
          id: string;
          session_id: string;
          sender_id: string;
          content: string;
          is_read: boolean;
          created_at: string;
        };
      };
      notifications: {
        Row: {
          id: string;
          user_id: string;
          type: string;
          title: string;
          message: string;
          data: Json;
          is_read: boolean;
          created_at: string;
        };
      };
      skill_categories: {
        Row: {
          id: string;
          name: string;
          description: string | null;
          icon: string | null;
          color: string | null;
          parent_id: string | null;
          sort_order: number;
          is_active: boolean;
          created_at: string;
        };
      };
      credit_packages: {
        Row: {
          id: string;
          name: string;
          credits: number;
          price_usd: number;
          bonus_credits: number;
          description: string | null;
          stripe_price_id: string | null;
          is_active: boolean;
          sort_order: number;
          created_at: string;
        };
      };
      subscription_plans: {
        Row: {
          id: string;
          name: string;
          description: string | null;
          price_monthly_usd: number;
          price_yearly_usd: number | null;
          features: Json;
          credits_included_monthly: number;
          featured_listings_included: number;
          verification_included: boolean;
          priority_support: boolean;
          analytics_access: boolean;
          commission_discount_percent: number;
          is_active: boolean;
          stripe_price_id_monthly: string | null;
          stripe_price_id_yearly: string | null;
          sort_order: number;
          created_at: string;
        };
      };
      user_subscriptions: {
        Row: {
          id: string;
          user_id: string;
          plan_id: string;
          stripe_subscription_id: string | null;
          stripe_customer_id: string | null;
          status: string;
          current_period_start: string | null;
          current_period_end: string | null;
          cancel_at_period_end: boolean;
          trial_end: string | null;
          created_at: string;
          updated_at: string;
        };
      };
      payouts: {
        Row: {
          id: string;
          user_id: string;
          credits_amount: number;
          usd_amount: number;
          platform_fee_deducted: number;
          net_amount: number;
          method: 'paypal' | 'bank_transfer' | 'crypto' | 'stripe';
          payout_email: string | null;
          status: 'pending' | 'processing' | 'completed' | 'rejected';
          processed_at: string | null;
          created_at: string;
        };
      };
      disputes: {
        Row: {
          id: string;
          session_id: string;
          opened_by: string;
          respondent_id: string;
          reason: string;
          description: string | null;
          evidence: Json;
          status: 'open' | 'under_review' | 'resolved_buyer' | 'resolved_seller' | 'rejected';
          resolution_notes: string | null;
          credits_refunded: number;
          resolved_by: string | null;
          created_at: string;
          resolved_at: string | null;
        };
      };
      platform_config: {
        Row: {
          id: number;
          platform_fee_percent: number;
          min_session_credits: number;
          max_session_credits: number;
          credit_purchase_bonus_percent: number;
          teacher_verification_cost_credits: number;
          featured_listing_cost_credits: number;
          featured_listing_duration_hours: number;
          dispute_window_hours: number;
          min_withdrawal_credits: number;
          credit_to_usd_rate: number;
          updated_at: string;
        };
      };
      admin_users: {
        Row: {
          id: string;
          user_id: string;
          role: 'super_admin' | 'admin' | 'moderator' | 'support';
          permissions: Json;
          last_login_at: string | null;
          created_at: string;
          updated_at: string;
        };
      };
      audit_log: {
        Row: {
          id: string;
          table_name: string;
          record_id: string | null;
          action: 'INSERT' | 'UPDATE' | 'DELETE';
          old_data: Json | null;
          new_data: Json | null;
          performed_by: string | null;
          ip_address: string | null;
          user_agent: string | null;
          created_at: string;
        };
      };
      stripe_events: {
        Row: {
          id: string;
          stripe_event_id: string;
          event_type: string;
          event_data: Json;
          processed: boolean;
          processed_at: string | null;
          error_message: string | null;
          created_at: string;
        };
      };
    };
    Views: {
      session_details: {
        Row: {
          [key: string]: unknown;
        };
      };
      user_stats: {
        Row: {
          [key: string]: unknown;
        };
      };
      platform_revenue_summary: {
        Row: {
          [key: string]: unknown;
        };
      };
    };
    Functions: {
      get_platform_stats: {
        Returns: {
          total_users: number;
          active_users: number;
          total_sessions: number;
          completed_sessions: number;
          total_credits_in_circulation: number;
          total_credits_purchased: number;
          total_platform_fees: number;
          avg_session_rating: number;
          pending_payouts: number;
          open_disputes: number;
        };
      };
      get_top_teachers: {
        Args: { limit_count: number };
        Returns: {
          user_id: string;
          username: string;
          display_name: string;
          total_earned: number;
          sessions_taught: number;
          avg_rating: number;
          skills_teaching: string[];
        }[];
      };
      refresh_revenue_summary: {
        Returns: void;
      };
    };
    Enums: {
      session_status: 'pending' | 'accepted' | 'scheduled' | 'in_progress' | 'completed' | 'cancelled' | 'disputed';
      session_format: 'video' | 'chat' | 'in_person';
      transaction_type: 'earn' | 'spend' | 'purchase' | 'bonus' | 'refund' | 'penalty';
      payout_status: 'pending' | 'processing' | 'completed' | 'rejected';
      payout_method: 'paypal' | 'bank_transfer' | 'crypto' | 'stripe';
      dispute_status: 'open' | 'under_review' | 'resolved_buyer' | 'resolved_seller' | 'rejected';
    };
  };
}
