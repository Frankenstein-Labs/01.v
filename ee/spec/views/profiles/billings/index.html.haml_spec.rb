# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'profiles/billings/index.html.haml', :saas, feature_category: :subscription_management do
  include StubRequests
  include SubscriptionPortalHelpers

  let(:namespace) { build_stubbed(:namespace) }
  let(:user) { build_stubbed(:user, namespace: namespace) }
  let(:free_group) { build_stubbed(:group) }
  let(:trial_group) { build_stubbed(:group) }
  let(:premium_plan) { Hashie::Mash.new(code: ::Plan::PREMIUM, id: 1, name: 'Premium') }
  let(:ultimate_plan) { Hashie::Mash.new(code: ::Plan::ULTIMATE, id: 2, name: 'Ultimate') }
  let(:plans_data) { [premium_plan, ultimate_plan] }

  before do
    stub_signing_key
    stub_application_setting(check_namespace_plan: true)
    assign(:plans_data, plans_data)

    allow(user).to receive_messages(
      free_or_trial_owned_group_ids: [1, 2]
    )
    allow(user).to receive_message_chain(:owned_groups, :free_or_trial, :not_aimed_for_deletion,
      :include_gitlab_subscription).and_return([free_group, trial_group])

    allow(free_group).to receive_messages(
      id: 1,
      name: 'Free Group',
      trial_active?: false
    )
    allow(trial_group).to receive_messages(
      id: 2,
      name: 'Trial Group',
      trial_active?: true
    )

    allow(view).to receive_messages(current_user: user, group_billings_path: '/groups/1/-/billings',
      plan_purchase_url: '/purchase', dashboard_groups_path: '/dashboard/groups')
    allow(view).to receive(:add_page_specific_style)
  end

  it 'renders the pricing information component' do
    render

    expect(rendered).to have_css('#js-pricing-information')
  end

  it 'passes data attributes as JSON to the component' do
    render

    page = Capybara.string(rendered)
    element = page.find('#js-pricing-information')

    expect(element['data-view-model']).to be_present

    data = ::Gitlab::Json.parse(element['data-view-model'])
    expect(data).to be_a(Hash)
    expect(data).to have_key('groups')
    expect(data['groups']).to be_an(Array)
    expect(data).to have_key('dashboardGroupsHref')
  end
end
