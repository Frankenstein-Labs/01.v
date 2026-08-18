# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project settings > [EE] Merge Request Approvals', :js, feature_category: :code_review_workflow do
  include GitlabRoutingHelper
  include FeatureApprovalHelper
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, namespace: group) }
  let_it_be(:group_member) { create(:user) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:config_selector) { '[data-testid="mr-approval-rules"]' }
  let_it_be(:modal_selector) { '#project-settings-approvals-create-modal' }
  let_it_be(:users_testid) { 'users-selector' }
  let_it_be(:groups_testid) { 'groups-selector' }

  before do
    sign_in(user)

    stub_licensed_features(merge_request_approvers: true)

    project.add_maintainer(user)
    group.add_developer(user)
    group.add_developer(group_member)
  end

  it 'adds approver' do
    visit project_settings_merge_requests_path(project)

    click_button('Add approval rule')
    search(user.name, users_testid)

    expect_listbox_item(user.name)
    expect_no_listbox_item(non_member.name)

    select_listbox_item(user.name)

    expect(find_by_testid(users_testid)).to have_content(user.name)

    search(user.name, users_testid)

    expect_no_listbox_item(user.name)

    within('.gl-drawer') do
      click_button 'Save changes'
    end
    wait_for_requests

    expect_avatar(find_by_testid('approvals-table-members'), user)
  end

  it 'adds approver group' do
    visit project_settings_merge_requests_path(project)

    click_button('Add approval rule')
    search(group.name, groups_testid)

    expect_listbox_item(group.name)

    select_listbox_item(group.name)

    expect(find_by_testid(groups_testid)).to have_content(group.name)

    within('.gl-drawer') do
      click_button 'Save changes'
    end
    wait_for_requests

    group_users = group.group_members.preload_users.map(&:user)
    expect_avatar(find_by_testid('approvals-table-members'), group_users)
  end

  context 'with an approver group' do
    let_it_be_with_reload(:non_group_approver) { create(:user) }
    let_it_be_with_reload(:rule) do
      create(:approval_project_rule, project: project, groups: [group], users: [non_group_approver])
    end

    before do
      project.add_developer(non_group_approver)
    end

    it 'removes approver group' do
      visit project_settings_merge_requests_path(project)

      expect_avatar(find_by_testid('approvals-table-members'), rule.approvers)
      wait_for_requests
      within(find_by_testid('approvals-table-controls')) do
        click_button 'Edit'
      end
      remove_approver(group.name, '.gl-drawer-body')
      within('.gl-drawer') do
        click_button 'Save changes'
      end
      wait_for_requests

      expect_avatar(find_by_testid('approvals-table-members'), [non_group_approver])
    end
  end
end
