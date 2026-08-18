# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::GitlabSubscriptions::TrialUsageResolver, feature_category: :consumables_cost_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }
  let(:trial_usage_response) do
    {
      success: true,
      trialUsage: {
        activeTrial: {
          startDate: '2026-02-01',
          endDate: '2026-03-03'
        },
        usersUsage: {
          creditsUsed: 45.8,
          totalUsersUsingCredits: 3
        }
      }
    }
  end

  before_all do
    group.add_owner(user)
  end

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    allow(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new).and_return(subscription_usage_client)
    allow(subscription_usage_client).to receive(:get_trial_usage).and_return(trial_usage_response)
  end

  describe '#resolve' do
    context 'with namespace_path argument' do
      it 'returns a TrialsUsage::Base instance' do
        result = resolve_trial_usage(namespace_path: group.full_path)

        expect(result).to be_a(GitlabSubscriptions::TrialsUsage::Base)
        expect(result.namespace).to eq(group)
      end

      it 'initializes SubscriptionUsageClient with namespace_id' do
        expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new)
          .with(namespace_id: group.id)
          .and_return(subscription_usage_client)

        resolve_trial_usage(namespace_path: group.full_path)
      end
    end

    context 'without namespace_path argument (instance)' do
      let_it_be(:admin) { create(:admin) }
      let(:license) { create(:license) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it 'returns a TrialsUsage::Base instance for instance subscription', :enable_admin_mode do
        result = resolve_trial_usage(current_user: admin)

        expect(result).to be_a(GitlabSubscriptions::TrialsUsage::Base)
      end

      it 'initializes SubscriptionUsageClient with license_key', :enable_admin_mode do
        expect(Gitlab::SubscriptionPortal::SubscriptionUsageClient).to receive(:new)
          .with(license_key: license.data)
          .and_return(subscription_usage_client)

        resolve_trial_usage(current_user: admin)
      end
    end
  end

  def resolve_trial_usage(args = {}, context = {})
    resolve(described_class, args: args, ctx: { current_user: args[:current_user] || user }.merge(context))
  end
end
