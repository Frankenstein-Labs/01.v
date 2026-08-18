# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Free User Cap > Pre-Enforcement Alert > Hand Raise Lead', :js, :saas, feature_category: :seat_cost_management do
  include Features::HandRaiseLeadHelpers
  include FreeUserCapHelpers
  include NamespaceStorageHelpers

  let_it_be(:user) { create(:user, :with_namespace, company: 'GitLab') }
  let_it_be_with_reload(:group) do
    create(:group_with_plan, :with_root_storage_statistics, :private, plan: :free_plan)
  end

  before_all do
    group.add_owner(user)
  end

  before do
    stub_feature_flags(free_user_cap_without_storage_check: false)

    set_dashboard_limit(group, megabytes: 5_000)
    set_used_storage(group, megabytes: 6_000)

    exceed_user_cap(group)
    enforce_free_user_caps

    sign_in(user)

    visit group_path(group)
  end

  it 'renders and submits when user interacts with hand raise lead trigger in the pre-enforcement banner' do
    within_testid('pre-enforcement-user-limit-alert') do
      find_button('Contact sales').click
    end

    expect_fill_in_and_submit_hand_raise_lead(user, group, glm_content: 'pre-enforcement-user-limit')
  end
end
