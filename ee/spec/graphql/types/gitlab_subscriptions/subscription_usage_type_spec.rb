# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsage'], feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsage') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([
      :enabled,
      :is_outdated_client,
      :last_event_transaction_at,
      :start_date,
      :end_date,
      :purchase_credits_path,
      :credits_used,
      :daily_usage,
      :daily_average,
      :monthly_waiver,
      :monthly_commitment,
      :products,
      :budget_caps,
      :overage,
      :users_usage,
      :paid_tier_trial,
      :overage_terms_accepted,
      :can_accept_overage_terms,
      :dap_promo_enabled,
      :subscription_portal_usage_dashboard_url
    ])
  end

  describe '#daily_usage' do
    let(:subscription_usage) { instance_double(GitlabSubscriptions::SubscriptionUsage) }
    let(:type) { described_class.send(:new, subscription_usage, {}) }

    it 'delegates to the object with sort and limit' do
      expect(subscription_usage).to receive(:daily_usage).with(sort: :date_asc, limit: nil)
      type.daily_usage
    end
  end
end
