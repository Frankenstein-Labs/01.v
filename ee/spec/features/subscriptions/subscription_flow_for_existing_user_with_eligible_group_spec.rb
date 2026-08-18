# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Subscription flow for existing user with eligible group', :js, feature_category: :subscription_management do
  include SaasRegistrationHelpers
  include SubscriptionPortalHelpers

  let_it_be(:user) { create(:user) }.freeze

  let_it_be(:group) { create(:group, name: 'Existing Group', owners: user) }.freeze

  before do
    stub_signing_key
    stub_eligible_namespaces
    stub_subscription_plans

    sign_in(user)
  end

  it 'redirects to subscription group selection page' do
    visit new_subscriptions_path(plan_id: premium_plan_id)

    expect_to_see_subscription_group_selection_form
  end

  def stub_eligible_namespaces
    allow(Gitlab::SubscriptionPortal::Client)
      .to receive(:filter_purchase_eligible_namespaces)
            .and_return(
              success: true,
              data: [
                { 'id' => group.id, 'accountId' => nil, 'subscription' => nil }
              ])
  end
end
