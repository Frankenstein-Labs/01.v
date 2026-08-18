# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Filter work items by status', :js, feature_category: :planning_views do
  include FilteredSearchHelpers
  include ListboxHelpers

  let_it_be(:to_do_status_id) { WorkItems::Statuses::SystemDefined::Status.find_by_name('To do').id }
  let_it_be(:in_progress_status_id) { WorkItems::Statuses::SystemDefined::Status.find_by_name('In progress').id }
  let_it_be(:done_status_id) { WorkItems::Statuses::SystemDefined::Status.find_by_name('Done').id }

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group, developers: [user]) }

  let_it_be(:to_do_issue) { create(:issue, project: project) }
  let_it_be(:to_do_issue_current_status) do
    create(:work_item_current_status, work_item_id: to_do_issue.id, system_defined_status_id: to_do_status_id)
  end

  let_it_be(:in_progress_issue) { create(:issue, project: project) }
  let_it_be(:in_progress_issue_current_status) do
    create(:work_item_current_status, work_item_id: in_progress_issue.id,
      system_defined_status_id: in_progress_status_id)
  end

  let_it_be(:done_issue) { create(:issue, project: project) }
  let_it_be(:done_issue_current_status) do
    create(:work_item_current_status, work_item_id: done_issue.id, system_defined_status_id: done_status_id)
  end

  let_it_be(:done_task) { create(:work_item, :task, project: project) }
  let_it_be(:done_task_current_status) do
    create(:work_item_current_status, work_item_id: done_task.id, system_defined_status_id: done_status_id)
  end

  shared_examples 'filtering by custom status' do
    context 'when custom status feature is enabled' do
      before do
        stub_licensed_features(work_item_status: true)
        sign_in(user)
        visit issues_page_path
      end

      it 'allows filtering by status', :aggregate_failures do
        select_tokens 'Status', 'To do', submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_css('.issue [data-testid="work-item-status-badge"]', text: 'To do', count: 1)
        expect(page).to have_link(to_do_issue.title)

        click_button 'Clear'

        select_tokens 'Status', 'In progress', submit: true

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_css('.issue [data-testid="work-item-status-badge"]', text: 'In progress', count: 1)
        expect(page).to have_link(in_progress_issue.title)

        click_button 'Clear'

        select_tokens 'Status', 'Done', submit: true

        expect(page).to have_css('.issue', count: 2)
        expect(page).to have_css('.issue [data-testid="work-item-status-badge"]', text: 'Done', count: 2)
        expect(page).to have_link(done_issue.title)
        expect(page).to have_link(done_task.title)

        click_button 'Clear'

        select_tokens 'Status', 'Duplicate', submit: true

        expect(page).to have_css('.issue', count: 0)
      end
    end

    context 'when custom status feature is disabled' do
      before do
        stub_licensed_features(work_item_status: false)
        sign_in(user)
        visit issues_page_path
      end

      it 'does not show "Status" token in filtered search' do
        click_filtered_search_bar

        expect_no_suggestion('Status')
      end
    end
  end

  context 'on group issues page' do
    let(:issues_page_path) { group_work_items_path(group) }

    it_behaves_like 'filtering by custom status'
  end

  context 'on project issues page' do
    let(:issues_page_path) { project_work_items_path(project) }

    it_behaves_like 'filtering by custom status'
  end
end
