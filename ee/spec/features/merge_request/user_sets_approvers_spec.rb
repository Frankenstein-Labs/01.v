# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Merge request > User sets approvers', :js, feature_category: :code_review_workflow do
  include ProjectForksHelper
  include FeatureApprovalHelper
  include ListboxHelpers

  let(:user) { create(:user) }
  let(:project) { create(:project, :public, :repository) }
  let(:config_selector) { '[data-testid="mr-approval-rules"]' }
  let(:drawer_selector) { '.gl-drawer' }
  let_it_be(:users_testid) { 'users-selector' }
  let_it_be(:groups_testid) { 'groups-selector' }

  before do
    stub_licensed_features(merge_request_approvers: true)
  end

  context 'when editing an MR with a different author' do
    let(:author) { create(:user) }
    let(:merge_request) { create(:merge_request, author: author, source_project: project) }

    before do
      project.add_maintainer(user)
      project.add_maintainer(author)

      sign_in(user)
      visit edit_project_merge_request_path(project, merge_request)
    end

    it 'does not allow setting the author as an approver but allows setting the current user as an approver' do
      click_button('Approval rules')
      click_button('Add approval rule')
      search(user.name, users_testid)

      expect_no_listbox_item(author.name)
      expect_listbox_item(user.name)
    end
  end

  context 'when creating an MR from a fork' do
    let(:other_user) { create(:user) }
    let(:non_member) { create(:user) }
    let(:forked_project) { fork_project(project, user, repository: true) }

    before do
      project.add_maintainer(user)
      project.add_maintainer(other_user)

      sign_in(user)
      visit project_new_merge_request_path(forked_project, merge_request: { target_branch: 'master', source_branch: 'feature' })
    end

    it 'allows setting other users as approvers but does not allow setting the current user as an approver, and filters non members from approvers list', :sidekiq_might_not_need_inline do
      click_button('Approval rules')
      click_button('Add approval rule')
      search(other_user.name, users_testid)

      expect_listbox_item(other_user.name)
      expect_no_listbox_item(non_member.name)
    end
  end

  context "Group approvers" do
    let_it_be(:project) { create(:project, :public, :repository) }
    let_it_be(:group) { create(:group) }

    context 'when creating an MR' do
      let(:other_user) { create(:user) }

      before do
        project.add_maintainer(user)
        project.add_maintainer(other_user)
        group.add_maintainer(other_user)

        sign_in(user)
      end

      it 'allows setting groups as approvers', :sidekiq_inline do
        visit project_new_merge_request_path(project, merge_request: { target_branch: 'master', source_branch: 'feature' })

        click_button('Approval rules')
        click_button('Add approval rule')

        search(group.name, groups_testid)

        expect_no_listbox_item(group.name)

        group.add_maintainer(user) # only display groups that user has access to

        visit project_new_merge_request_path(project, merge_request: { target_branch: 'master', source_branch: 'feature' })
        click_button('Approval rules')
        click_button('Add approval rule')

        within_testid(groups_testid) do
          click_button "Project groups"
          find_by_testid("listbox-item-false").click
        end

        search(group.name, groups_testid)

        expect_listbox_item(group.name)

        select_listbox_item(group.name)

        within(drawer_selector) do
          click_button 'Save changes'
        end
        expect(page).to have_no_css(drawer_selector)

        click_on("Create merge request")
        wait_for_all_requests

        expect(page).to have_content("Requires 1 approval from eligible users.")
      end

      it 'allows delete approvers group when it is set in project', :sidekiq_inline do
        approver = create :user
        project.add_maintainer(approver)
        group.add_maintainer(approver)
        create :approval_project_rule, project: project, users: [approver], groups: [group], approvals_required: 1

        visit project_new_merge_request_path(project, merge_request: { target_branch: 'master', source_branch: 'feature' })

        click_button('Approval rules')
        within(find_by_testid('approvals-table-controls')) do
          click_button 'Edit'
        end
        remove_approver(group.name, '.gl-drawer-body')

        within(drawer_selector) do
          click_button 'Save changes'
        end

        click_on("Create merge request")
        wait_for_all_requests
        click_button 'Expand eligible approvers'
        wait_for_requests

        expect(page).to have_selector(".js-approvers img[alt='#{approver.name}']")
      end
    end

    context 'when editing an MR with a different author' do
      let(:other_user) { create(:user) }
      let(:merge_request) { create(:merge_request, source_project: project) }

      before do
        project.add_maintainer(user)

        sign_in(user)
      end

      it 'allows setting groups as approvers when there is possible group approvers' do
        group = create :group
        group_project = create(:project, :public, :repository, namespace: group)
        group_project_merge_request = create(:merge_request, source_project: group_project)
        group.add_maintainer(user)
        group.add_maintainer(other_user)

        visit edit_project_merge_request_path(group_project, group_project_merge_request)

        click_button('Approval rules')
        click_button('Add approval rule')
        search(group.name, groups_testid)

        expect_listbox_item(group.name)

        select_listbox_item(group.name)
        within(drawer_selector) do
          click_button 'Save changes'
        end
        expect(page).to have_no_css(drawer_selector)

        click_on("Save changes")
        wait_for_all_requests

        expect(page).to have_content("Requires 1 approval from eligible users.")
      end

      it 'allows delete approvers group when it`s set in project' do
        approver = create :user
        project.add_maintainer(approver)
        group = create :group
        group.add_maintainer(other_user)
        group.add_maintainer(approver)
        create :approval_project_rule, project: project, users: [approver], groups: [group], approvals_required: 1

        visit edit_project_merge_request_path(project, merge_request)

        click_button('Approval rules')
        within(find_by_testid('approvals-table-controls')) do
          click_button 'Edit'
        end
        remove_approver(group.name, '.gl-drawer-body')

        wait_for_requests
        within(drawer_selector) do
          click_button 'Save changes'
        end
        expect(page).to have_no_css(drawer_selector)

        click_on("Save changes")
        wait_for_all_requests

        click_button 'Expand eligible approvers'
        wait_for_requests

        expect(page).to have_selector(".js-approvers img[alt='#{approver.name}']")
        expect(page).to have_content("Requires 1 approval from eligible users.")
        expect(page).not_to have_selector(".js-approvers img[alt='#{other_user.name}']")
      end

      it 'allows changing approvals number' do
        approvers = create_list(:user, 3)
        approvers.each { |approver| project.add_maintainer(approver) }
        create :approval_project_rule, project: project, users: approvers, approvals_required: 2

        visit project_merge_request_path(project, merge_request)
        wait_for_requests

        # project setting in the beginning on the show MR page
        expect(page).to have_content("Requires 2 approvals from eligible users")

        find('.detail-page-header').click_on 'Edit'
        click_button('Approval rules')
        within(find_by_testid('approvals-table-controls')) do
          click_button 'Edit'
        end

        within(drawer_selector) do
          expect(page).to have_field 'Required number of approvals', with: '2'

          fill_in 'Required number of approvals', with: '3'

          click_button 'Save changes'
        end
        expect(page).to have_no_css(drawer_selector)

        click_on('Save changes')
        wait_for_all_requests

        # new MR setting on the show MR page
        expect(page).to have_content("Requires 3 approvals from eligible users")

        # new MR setting on the edit MR page
        find('.detail-page-header').click_on 'Edit'
        click_button('Approval rules')
        within(find_by_testid('approvals-table-controls')) do
          click_button 'Edit'
        end

        expect(page).to have_field 'Required number of approvals', with: '3'
      end
    end
  end
end
