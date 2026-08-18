# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request > User edits MR with approval rules', :js, feature_category: :code_review_workflow do
  include ListboxHelpers
  include FeatureApprovalHelper

  include_context 'with project with approval rules'

  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:approver, freeze: false) { create(:user) }
  let_it_be(:mr_rule_names) { %w[foo lorem ipsum] }
  let_it_be(:users_testid) { 'users-selector' }
  let_it_be(:groups_testid) { 'groups-selector' }
  let_it_be(:mr_rules) do
    mr_rule_names.map do |name|
      create(
        :approval_merge_request_rule,
        merge_request: merge_request,
        approvals_required: 1,
        name: name,
        users: [approver]
      )
    end
  end

  def page_rule_names
    page.all('[data-testid="approvals-table-name"]')
  end

  before do
    project.update!(disable_overriding_approvers_per_merge_request: false)
    stub_licensed_features(multiple_approval_rules: true)

    sign_in(author)
  end

  context 'when editing the merge request' do
    before do
      visit(edit_project_merge_request_path(project, merge_request))

      wait_for_requests
    end

    it "shows approval rules" do
      click_button 'Approval rules'

      names = page_rule_names.map(&:text)

      expect(names).to eq(mr_rule_names)
    end

    it "allows user to create approval rule" do
      click_button 'Approval rules'

      rule_name = "Custom Approval Rule"

      click_button "Add approval rule"

      within('.gl-drawer') do
        fill_in 'Rule name', with: rule_name
        search(approver.name, users_testid)
        select_listbox_item(approver.name)
        click_button 'Save changes'
      end

      expect(page_rule_names.last).to have_text(rule_name)
    end
  end

  context 'with public group' do
    let_it_be(:group) { create(:group, :public) }
    let_it_be(:public_group) { create(:group, :public) }

    before do
      group_project = create(:project, :public, :repository, namespace: group)
      group_project_merge_request = create(:merge_request, source_project: group_project)
      group.add_maintainer(author)

      visit(edit_project_merge_request_path(group_project, group_project_merge_request))

      wait_for_requests

      click_button 'Approval rules'
      click_button "Add approval rule"
    end

    it "with empty search, does not show public group" do
      search(public_group.name, groups_testid)

      expect_no_listbox_item(public_group.name)
    end

    it "with non-empty search, shows public group" do
      within_testid('groups-selector') do
        click_button "Project groups"
        find_by_testid("listbox-item-false").click
      end
      search(public_group.name, groups_testid)

      expect_listbox_item(public_group.name)
    end
  end

  context 'feature is disabled' do
    before do
      stub_licensed_features(merge_request_approvers: false)

      visit(edit_project_merge_request_path(project, merge_request))
    end

    it 'cannot see the approval rules input' do
      expect(page).not_to have_content('Approval rules')
    end
  end
end
