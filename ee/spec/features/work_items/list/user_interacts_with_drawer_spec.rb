# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work Items List Drawer', :js, feature_category: :planning_views do
  include WorkItemsHelpers
  include ListboxHelper
  include Features::IterationHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:issue) { create(:work_item, :issue, project: project) }
  let_it_be(:epic) { create(:work_item, :epic, namespace: group) }
  let_it_be(:label) { create(:label, project: project, title: "testing-label") }
  let_it_be(:label_group) { create(:group_label, title: 'Label 1', group: group) }
  let_it_be(:milestone) { create(:milestone, project: project) }
  let_it_be(:milestone_group) { create(:milestone, group: group, due_date: '2017-01-01', title: 'Second Title') }
  let_it_be(:cadence) { create(:iterations_cadence, group: project.group) }
  let_it_be(:iteration) do
    create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 2.days.ago)
  end

  shared_examples 'updates weight of a work item on the list' do
    it 'updates weight of a work item on the list', :aggregate_failures do
      within_testid('work-item-detail-panel') do
        within_testid 'work-item-weight' do
          click_button 'Edit'
          send_keys(3, :enter)

          wait_for_requests
        end

        close_drawer
      end

      expect(find_by_testid('issuable-weight-content-title').text).to have_text(3)
    end
  end

  shared_examples 'updates health status of a work item on the list' do
    it 'updates health status of a work item on the list', :aggregate_failures do
      within_testid('work-item-detail-panel') do
        within_testid 'work-item-health-status' do
          click_button 'Edit'
          select_listbox_item 'At risk'
        end

        close_drawer
      end

      expect(find_by_testid('status-text').text).to have_text('At risk')
    end
  end

  shared_examples 'updates iteration of a work item on the list' do
    it 'updates iteration of a work item on the list', :aggregate_failures do
      within_testid('work-item-detail-panel') do
        within_testid 'work-item-iteration' do
          click_button 'Edit'
          send_keys(iteration.title)
          select_listbox_item(iteration_period(iteration, use_thin_space: false))
        end

        close_drawer
      end

      expect(find_by_testid('iteration-attribute')).to have_content(iteration_period(iteration,
        use_thin_space: false))
    end
  end

  context 'if user is signed in as developer' do
    let(:issuable_container) { '[data-testid="issuable-container"]' }

    before_all do
      group.add_developer(user)
    end

    context 'when accessing work item from project work item list' do
      before do
        stub_licensed_features(epics: true, issuable_health_status: true, iterations: true)

        sign_in(user)

        visit project_work_items_path(project)

        first_card.click

        wait_for_requests
      end

      include_examples 'updates weight of a work item on the list'
      include_examples 'updates health status of a work item on the list'
      include_examples 'updates iteration of a work item on the list'
    end

    context 'when accessing work item from group work item list' do
      before do
        stub_licensed_features(epics: true, issuable_health_status: true, iterations: true)

        sign_in(user)

        visit group_work_items_path(group)

        first_card.click

        wait_for_requests
      end

      it_behaves_like 'work item drawer on the list page'

      context 'with quarantine', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/570546' do
        include_examples 'updates weight of a work item on the list'
      end

      include_examples 'updates health status of a work item on the list'
      include_examples 'updates iteration of a work item on the list'
    end

    context 'when accessing work item from group epics list' do
      before do
        stub_licensed_features(epics: true, issuable_health_status: true, iterations: true)

        sign_in(user)

        visit group_epics_path(group)

        first_card.click

        wait_for_requests
      end

      it_behaves_like 'work item drawer on the list page' do
        let(:issue) { epic }
        let(:label) { label_group }
        let(:milestone) { milestone_group }
      end

      it_behaves_like 'updates health status of a work item on the list' do
        let(:issue) { epic }
      end
    end
  end

  def first_card
    find_work_item_element(issue.id)
  end
end
