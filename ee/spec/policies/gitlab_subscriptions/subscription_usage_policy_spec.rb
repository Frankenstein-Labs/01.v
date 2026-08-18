# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionUsagePolicy, feature_category: :consumables_cost_management do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }
  let_it_be(:group) { create(:group) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user, owner_of: group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  shared_examples 'subscription usage policy' do |permission|
    context 'when namespace is present' do
      let(:subscription_usage) do
        GitlabSubscriptions::SubscriptionUsage.new(
          subscription_target: :namespace,
          subscription_usage_client: subscription_usage_client,
          namespace: group
        )
      end

      where(:user, :admin_mode, :allowed) do
        ref(:guest)      | nil   | false
        ref(:reporter)   | nil   | false
        ref(:developer)  | nil   | false
        ref(:maintainer) | nil   | false
        ref(:owner)      | nil   | true
        ref(:admin)      | true  | true
        ref(:admin)      | false | false
      end

      with_them do
        subject { described_class.new(user, subscription_usage) }

        before do
          enable_admin_mode!(user) if admin_mode
        end

        it { allowed ? expect_allowed(permission) : expect_disallowed(permission) }
      end
    end

    context 'when namespace is nil, in Self-Managed instance context' do
      let(:subscription_usage) do
        GitlabSubscriptions::SubscriptionUsage.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      where(:user, :admin_mode, :allowed) do
        ref(:guest)      | nil   | false
        ref(:reporter)   | nil   | false
        ref(:developer)  | nil   | false
        ref(:maintainer) | nil   | false
        ref(:owner)      | nil   | false
        ref(:admin)      | true  | true
        ref(:admin)      | false | false
      end

      with_them do
        subject { described_class.new(user, subscription_usage) }

        before do
          enable_admin_mode!(user) if admin_mode
        end

        it { allowed ? expect_allowed(permission) : expect_disallowed(permission) }
      end
    end
  end

  describe ':read_subscription_usage' do
    it_behaves_like 'subscription usage policy', :read_subscription_usage
  end

  describe ':update_subscription_usage_cap' do
    it_behaves_like 'subscription usage policy', :update_subscription_usage_cap
  end
end
