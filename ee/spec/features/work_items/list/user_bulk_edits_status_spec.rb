# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Bulk edit status', :js, feature_category: :planning_views do
  include WorkItemsHelpers

  let_it_be(:to_do_status_id) { WorkItems::Statuses::SystemDefined::Status.find_by_name('To do').id }

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: [user]) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:to_do_issue) { create(:issue, project: project) }
  let_it_be(:to_do_issue_current_status) do
    create(:work_item_current_status, work_item_id: to_do_issue.id, system_defined_status_id: to_do_status_id)
  end

  let_it_be(:to_do_task) { create(:work_item, :task, project: project) }
  let_it_be(:to_do_task_current_status) do
    create(:work_item_current_status, work_item_id: to_do_task.id, system_defined_status_id: to_do_status_id)
  end

  shared_examples 'bulk editing status' do
    context 'when bulk editing' do
      before do
        sign_in(user)
        stub_licensed_features(group_bulk_edit: true, work_item_status: true)
        visit work_items_path
      end

      it 'bulk edits status' do
        expect(find_work_item_element(to_do_issue.id)).to have_css('[data-testid="work-item-status-badge"]',
          text: 'To do')
        expect(find_work_item_element(to_do_task.id)).to have_css('[data-testid="work-item-status-badge"]',
          text: 'To do')

        click_button 'Bulk edit'
        check_work_items([to_do_issue.title, to_do_task.title])
        click_button 'Select status'
        select_listbox_item('In progress')
        click_button 'Update selected'

        expect(find_work_item_element(to_do_issue.id)).to have_css('[data-testid="work-item-status-badge"]',
          text: 'In progress')
        expect(find_work_item_element(to_do_task.id)).to have_css('[data-testid="work-item-status-badge"]',
          text: 'In progress')
      end
    end
  end

  context 'on group work items list' do
    let(:work_items_path) { group_work_items_path(group) }

    it_behaves_like 'bulk editing status'
  end

  context 'on project work items list' do
    let(:work_items_path) { project_work_items_path(project) }

    it_behaves_like 'bulk editing status'
  end
end
