# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Member Role Promotion Management', :js, feature_category: :seat_cost_management do
  include Features::InviteMembersModalHelpers
  include Features::MembersHelpers

  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:developer) { create(:user) }

  let(:group) { create(:group) }

  before do
    stub_ee_application_setting(enable_member_promotion_management: true)

    allow(License).to receive(:current).and_return(license)

    group.add_owner(owner)
    sign_in(owner)
    visit group_group_members_path(group)
    invite_member(developer.username, role: 'Developer')
    visit current_path
  end

  it 'asserts member role promotion `approval` flow',
    quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/532497' do
    expect_pending_member

    act_on_pending_member_as_admin('Approve')

    visit group_group_members_path(group)
    expect(find_member_row(developer)).to have_text('Developer')
  end

  it 'asserts member role promotion `rejection` flow',
    quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/565905' do
    expect_pending_member

    act_on_pending_member_as_admin('Reject')

    visit group_group_members_path(group)
    expect(page).not_to have_text(developer.username)
    expect(has_testid?('admin-promotion-request-tab')).to be(false)
  end

  def expect_pending_member
    expect(page).not_to have_text(developer.username)

    find_by_testid('promotion-request-tab').click
    expect(page).to have_text(developer.username)
  end

  def act_on_pending_member_as_admin(approval_action)
    sign_out(owner)
    gitlab_sign_in(admin)
    enable_admin_mode!(admin)

    visit admin_users_path
    find_by_testid('admin-promotion-request-tab').click
    expect(page).to have_text(developer.username)
    click_button approval_action

    sign_out(admin)
    gitlab_sign_in(owner)
  end
end
