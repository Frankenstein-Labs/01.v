# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Change type action', :js, feature_category: :portfolio_management do
  include ListboxHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :nested) }
  let_it_be(:project) { create(:project, :public, namespace: group, developers: user) }
  let_it_be(:objective) { create(:work_item, :objective, project: project) }
  let_it_be(:key_result) { create(:work_item, :key_result, project: project) }
  let_it_be(:issue) { create(:work_item, :issue, project: project) }
  let_it_be(:milestone) { create(:milestone, project: project) }

  context 'for signed in user' do
    before do
      sign_in(user)

      stub_licensed_features(epics: true, okrs: true)
      stub_feature_flags(okrs_mvc: true)
    end

    context 'when work item type is objective' do
      before do
        visit project_work_item_path(project, objective.iid)
        wait_for_all_requests
      end

      it_behaves_like 'work items change type', 'Key Result', '[data-testid="work-item-keyresult-icon"]'
      it_behaves_like 'work items change type', 'Issue', '[data-testid="work-item-issue-icon"]'
      it_behaves_like 'work items change type', 'Task', '[data-testid="work-item-task-icon"]'

      context 'when objective has a child' do
        it 'does not allow changing the type' do
          within_testid 'work-item-tree' do
            find_by_testid('add-tree-child-button').click
            click_button "Existing Key Result"
            fill_in 'Search existing items', with: key_result.title
            click_button key_result.title
            send_keys :escape
            click_button "Add Key Result"
            wait_for_all_requests
          end
          page.refresh

          trigger_change_type('Task')

          expect(page).to have_button('Change type', disabled: true)
        end
      end

      context 'when there is chance of data loss' do
        message = _('Some fields are not present in %{type}. If you change type now, this information will be lost.')
        it 'renders the warning about the data loss',
          quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/3370' do
          within_testid 'work-item-milestone' do
            click_button 'Edit'
            send_keys "\"#{milestone.title}\""
            select_listbox_item(milestone.title)
          end

          trigger_change_type('Key result')

          expect(page).to have_button('Change type', disabled: false)

          within_testid 'change-type-warning-message' do
            expect(page).to have_content(format(message, type: 'key result'))
            expect(page).to have_content(s_('WorkItem|Milestone'))
          end
        end
      end
    end

    context 'when work item type is key result' do
      before do
        visit project_work_item_path(project, key_result.iid)
        wait_for_all_requests
      end

      it_behaves_like 'work items change type', 'Objective', '[data-testid="work-item-objective-icon"]'
      it_behaves_like 'work items change type', 'Issue', '[data-testid="work-item-issue-icon"]'
      it_behaves_like 'work items change type', 'Task', '[data-testid="work-item-task-icon"]'

      context 'when key result has a parent' do
        it 'does not allow changing type' do
          within_testid 'work-item-parent' do
            click_button 'Edit'
            find('input[role="combobox"]')
            send_keys(objective.title)
            select_listbox_item(objective.title)
          end

          expect(page).to have_content "added #{objective.to_reference} as parent item"

          trigger_change_type('Task')

          expect(page).to have_button('Change type', disabled: true)
        end
      end
    end

    context 'when user selects option `Epic (promote to group)' do
      before_all do
        group.add_owner(user)
      end

      before do
        visit project_work_item_path(project, issue.iid)
        wait_for_all_requests
      end

      it 'redirects to an epic' do
        # TODO: restore threshold after epic-work item sync
        # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/438295
        allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(130)
        trigger_change_type('Epic (Promote to group)')

        # wait for epic widget definitions
        wait_for_requests

        expect(page).to have_button('Change type', disabled: false)

        click_button s_('WorkItem|Change type')

        wait_for_all_requests

        expect(page).to have_current_path(group_work_item_path(group, 1))
      end
    end
  end

  def trigger_change_type(type)
    click_button _('More actions'), match: :first
    click_button s_('WorkItem|Change type')
    find_by_testid('work-item-change-type-select').select(type)
  end
end
