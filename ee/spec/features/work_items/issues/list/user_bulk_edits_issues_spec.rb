# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work items > Bulk edit issues', feature_category: :planning_views do
  include ListboxHelpers
  include Features::IterationHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:iteration) do
    create(:iteration, iterations_cadence: create(:iterations_cadence, group: group), title: "Iteration 1")
  end

  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:project_without_group) { create(:project, :public) }

  let!(:issue1) { create(:issue, project: project, title: "Issue 1") }
  let!(:issue2) { create(:issue, project: project, title: "Issue 2") }
  let!(:issue3) { create(:issue, project: project_without_group, title: "Issue 3") }

  shared_examples 'bulk edit option in sidebar' do |context|
    it 'is present when bulk edit is enabled' do
      enable_bulk_update(context)
      expect(page).to have_button('Bulk edit', disabled: true)
    end

    it 'is not present when bulk edit is disabled' do
      expect(page).not_to have_button('Bulk edit')
    end
  end

  shared_examples 'bulk edit health status' do |context|
    before do
      enable_bulk_update(context)
    end

    context 'for health_status', :js do
      context 'in all work items' do
        before do
          check 'Select all'
          select_from_listbox 'On track', from: 'Select health status'
          update_issues
        end

        it 'updates the health statuses', :aggregate_failures do
          expect(issue1.reload.health_status).to eq 'on_track'
          expect(issue2.reload.health_status).to eq 'on_track'
        end
      end

      context 'in a work item' do
        before do
          check issue1.title
          select_from_listbox 'At risk', from: 'Select health status'
          update_issues
        end

        it 'updates the checked issue\'s status', :aggregate_failures do
          expect(issue1.reload.health_status).to eq 'at_risk'
          expect(issue2.reload.health_status).to be_nil
        end
      end
    end
  end

  shared_examples 'bulk edit iteration' do |context|
    context 'for iteration', :js do
      before do
        enable_bulk_update(context)
      end

      context 'for all work items' do
        before do
          check issue1.title
          check issue2.title
          click_button 'Select iteration'
          wait_for_requests
          select_listbox_item(iteration_period(iteration, use_thin_space: false))
          update_issues
        end

        it 'updates the iteration', :aggregate_failures do
          expect(issue1.reload.iteration.name).to eq 'Iteration 1'
          expect(issue2.reload.iteration.name).to eq 'Iteration 1'
        end
      end
    end

    context 'when cannot find iteration when iterations is off', :js do
      before do
        stub_licensed_features(iterations: false)

        enable_bulk_update(context)
      end

      it 'cannot find iteration dropdown' do
        expect(page).not_to have_button 'Select iteration'
      end
    end
  end

  shared_examples 'cannot find iterations when project does not have a group' do |context|
    context 'when cannot find iteration when group does not belong to project', :js do
      before do
        project_without_group.add_maintainer(user)

        enable_bulk_update(context)
      end

      it 'cannot find iteration dropdown' do
        expect(page).not_to have_button 'Select iteration'
      end
    end
  end

  shared_examples 'bulk edit health_status with insufficient permissions' do
    it 'cannot bulk assign health_status', :aggregate_failures do
      expect(page).not_to have_button 'Bulk edit'
      expect(page).not_to have_unchecked_field 'Select all'
      expect(page).not_to have_unchecked_field issue1.title
    end
  end

  context 'as an allowed user', :js do
    before do
      allow(group).to receive(:feature_enabled?).and_return(true)

      stub_licensed_features(epics: true, group_bulk_edit: true, issuable_health_status: true, iterations: true)

      group.add_maintainer(user)

      sign_in user
    end

    context 'for group level' do
      before do
        # avoid raising QueryLimiting exception for bulk inserts
        allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(110)
      end

      it_behaves_like 'bulk edit option in sidebar', :group
      it_behaves_like 'bulk edit health status', :group
      it_behaves_like 'bulk edit iteration', :group
    end

    context 'for project level' do
      it_behaves_like 'bulk edit option in sidebar', :project
      it_behaves_like 'bulk edit health status', :project
      it_behaves_like 'bulk edit iteration', :project
      it_behaves_like 'cannot find iterations when project does not have a group', :project_without_group
    end
  end

  context 'as a guest', :js do
    before do
      allow(group).to receive(:feature_enabled?).and_return(true)

      stub_licensed_features(epics: true, group_bulk_edit: true, issuable_health_status: true, iterations: true)

      sign_in user
    end

    context 'for group level' do
      before do
        visit group_work_items_path(group)
      end

      it_behaves_like 'bulk edit health_status with insufficient permissions'
    end

    context 'for project level' do
      before do
        visit project_work_items_path(project)
      end

      it_behaves_like 'bulk edit health_status with insufficient permissions'
    end
  end

  def update_issues
    click_button 'Update selected'
    wait_for_requests
  end

  def enable_bulk_update(context)
    case context
    when :project
      visit project_work_items_path(project)
    when :project_without_group
      visit project_work_items_path(project_without_group)
    else
      visit group_work_items_path(group)
    end

    expect(page).to have_button('Bulk edit')
    wait_for_requests

    click_button 'Bulk edit'
  end
end
