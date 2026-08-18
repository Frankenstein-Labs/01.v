# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- using filter would need multiple creation with different criteria
RSpec.describe 'Work items list filters', :js, feature_category: :planning_views do
  include FilteredSearchHelpers
  include Features::IterationHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:sub_group_project) { create(:project, :public, group: sub_group, developers: user) }
  let_it_be(:sub_sub_group) { create(:group, parent: sub_group) }
  let_it_be(:project) { create(:project, :public, group: group, developers: user) }

  let_it_be(:epic) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
  let_it_be(:sub_epic) { create(:work_item, :epic_with_legacy_epic, namespace: sub_group) }
  let_it_be(:sub_issue) { create(:issue, project: sub_group_project) }
  let_it_be(:sub_sub_epic) { create(:work_item, :epic_with_legacy_epic, namespace: sub_sub_group) }

  let_it_be(:incident) { create(:incident, project: project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:task) { create(:work_item, :task, project: project) }
  let_it_be(:ticket) { create(:work_item, :ticket, project: project) }

  let_it_be(:weighted_issue_1) { create(:issue, project: project, weight: 1) }
  let_it_be(:weighted_issue_2) { create(:issue, project: project, weight: 2) }
  let_it_be(:weighted_issue_5) { create(:issue, project: project, weight: 5) }
  let_it_be(:unweighted_issue) { create(:issue, project: project, weight: nil) }

  let_it_be(:issue_on_track) { create(:issue, project: project, health_status: 'on_track') }
  let_it_be(:issue_needs_attention) { create(:issue, project: project, health_status: 'needs_attention') }
  let_it_be(:issue_at_risk) { create(:issue, project: project, health_status: 'at_risk') }
  let_it_be(:issue_no_health) { create(:issue, project: project, health_status: nil) }

  let_it_be(:iteration_cadence) { create(:iterations_cadence, group: group) }
  let_it_be(:iteration_cadence_2) { create(:iterations_cadence, group: group) }
  let_it_be(:iteration_1) do
    create(:iteration, iterations_cadence: iteration_cadence, title: 'Iteration 1', start_date: 8.weeks.ago,
      due_date: 6.weeks.ago)
  end

  let_it_be(:iteration_2) do
    create(:iteration, iterations_cadence: iteration_cadence, title: 'Iteration 2', start_date: 5.weeks.ago,
      due_date: 3.weeks.ago)
  end

  let_it_be(:iteration_from_cadence_2) do
    create(:iteration, iterations_cadence: iteration_cadence_2, title: 'Sprint Alpha', start_date: 4.weeks.ago,
      due_date: 2.weeks.ago)
  end

  let_it_be(:current_iteration) do
    create(:iteration, iterations_cadence: iteration_cadence, title: 'Current Sprint', start_date: Time.zone.today,
      due_date: 1.week.from_now)
  end

  let_it_be(:issue_with_iteration_1) { create(:issue, project: project, iteration: iteration_1) }
  let_it_be(:issue_with_iteration_2) { create(:issue, project: project, iteration: iteration_2) }
  let_it_be(:issue_with_iteration_from_cadence_2) do
    create(:issue, project: project, iteration: iteration_from_cadence_2)
  end

  let_it_be(:issue_with_current_iteration) { create(:issue, project: project, iteration: current_iteration) }
  let_it_be(:issue_without_iteration) { create(:issue, project: project, iteration: nil) }

  context 'for signed in user' do
    let(:licensed_features) do
      { epics: true, quality_management: true, subepics: true, issue_weights: true,
        issuable_health_status: true, work_item_status: true, iterations: true }
    end

    before do
      stub_licensed_features(**licensed_features)
      sign_in(user)
    end

    describe 'group' do
      before do
        visit group_work_items_path(group)
      end

      it 'filters', :aggregate_failures do
        select_tokens 'Group', group.name, submit: true

        wait_for_requests

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(epic.title)

        click_button 'Clear'

        select_tokens 'Group', sub_group.name, submit: true

        wait_for_requests

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(sub_epic.title)

        click_button 'Clear'

        select_tokens 'Group', sub_sub_group.name, submit: true

        wait_for_requests

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(sub_sub_epic.title)
      end
    end

    describe 'type' do
      before do
        visit group_work_items_path(group)
      end

      it 'filters', :aggregate_failures do
        select_tokens('Type', '=', 'Issue', submit: true)

        expect(page).to have_css('.issue', count: 15)
        expect(page).to have_link(issue.title)
        expect(page).to have_link(sub_issue.title)

        click_button 'Clear'

        select_tokens('Type', '=', 'Incident', submit: true)

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(incident.title)

        click_button 'Clear'

        select_tokens('Type', '=', 'Ticket', submit: true)

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(ticket.title)

        click_button 'Clear'

        select_tokens('Type', '=', 'Task', submit: true)

        expect(page).to have_css('.issue', count: 1)
        expect(page).to have_link(task.title)
      end
    end

    describe 'weight' do
      before do
        visit project_work_items_path(project)
      end

      describe 'behavior' do
        it 'loads all the weights when opened' do
          select_tokens 'Weight', '='

          # Expect None, Any, numbers 0 to 20
          expect_suggestion_count 23
        end
      end

      describe 'only weight' do
        it 'filters work items by searched weight' do
          select_tokens 'Weight', '=', '1', submit: true

          expect(page).to have_work_item_count(1)
          expect(page).to have_link(weighted_issue_1.title)
        end

        it 'filters work items by weight 2' do
          select_tokens 'Weight', '=', '2', submit: true

          expect(page).to have_work_item_count(1)
          expect(page).to have_link(weighted_issue_2.title)
        end

        it 'filters work items by weight 5' do
          select_tokens 'Weight', '=', '5', submit: true

          expect(page).to have_work_item_count(1)
          expect(page).to have_link(weighted_issue_5.title)
        end
      end

      describe 'weight wildcards' do
        it 'filters work items by None weight' do
          select_tokens 'Weight', '=', 'None', submit: true

          expect(page).to have_link(unweighted_issue.title)
          expect(page).not_to have_link(weighted_issue_1.title)
          expect(page).not_to have_link(weighted_issue_2.title)
          expect(page).not_to have_link(weighted_issue_5.title)
        end

        it 'filters work items by Any weight' do
          select_tokens 'Weight', '=', 'Any', submit: true

          expect(page).to have_work_item_count(3)
          expect(page).to have_link(weighted_issue_1.title)
          expect(page).to have_link(weighted_issue_2.title)
          expect(page).to have_link(weighted_issue_5.title)
          expect(page).not_to have_link(unweighted_issue.title)
        end
      end

      describe 'negated weight only' do
        it 'excludes work items with specified weight' do
          select_tokens 'Weight', '!=', '2', submit: true

          expect(page).to have_link(weighted_issue_1.title)
          expect(page).to have_link(weighted_issue_5.title)
          expect(page).to have_link(unweighted_issue.title)
          expect(page).not_to have_link(weighted_issue_2.title)
        end
      end

      context 'when issue weights feature is not available' do
        let(:licensed_features) { super().merge(issue_weights: false) }

        it 'does not show weight filter token' do
          click_filtered_search_bar

          expect(page).not_to have_css('[data-testid="filtered-search-token-segment"]', text: 'Weight')
        end
      end
    end

    describe 'health filter' do
      before do
        visit project_work_items_path(project)
      end

      describe 'behavior' do
        it 'loads all health status options when opened for =' do
          select_tokens 'Health', '='

          # Expect None, Any, on_track, needs_attention, and at_risk
          expect_suggestion_count 5
        end

        it 'loads all health status options when opened for !=' do
          select_tokens 'Health', '!='

          # Expect on_track, needs_attention, and at_risk
          expect_suggestion_count 3
        end
      end

      describe 'only health' do
        it 'filters work items by on_track health status' do
          select_tokens 'Health', '=', 'On track', submit: true

          expect(page).to have_work_item_count(1)
          expect(page).to have_link(issue_on_track.title)
        end

        it 'filters work items by needs_attention health status' do
          select_tokens 'Health', '=', 'Needs attention', submit: true

          expect(page).to have_work_item_count(1)
          expect(page).to have_link(issue_needs_attention.title)
        end

        it 'filters work items by at_risk health status' do
          select_tokens 'Health', '=', 'At risk', submit: true

          expect(page).to have_work_item_count(1)
          expect(page).to have_link(issue_at_risk.title)
        end
      end

      describe 'health wildcards' do
        it 'filters work items by None health status' do
          select_tokens 'Health', '=', 'None', submit: true

          expect(page).to have_link(issue_no_health.title)
          expect(page).not_to have_link(issue_on_track.title)
          expect(page).not_to have_link(issue_needs_attention.title)
          expect(page).not_to have_link(issue_at_risk.title)
        end

        it 'filters work items by Any health status' do
          select_tokens 'Health', '=', 'Any', submit: true

          expect(page).to have_work_item_count(3)
          expect(page).to have_link(issue_on_track.title)
          expect(page).to have_link(issue_needs_attention.title)
          expect(page).to have_link(issue_at_risk.title)
          expect(page).not_to have_link(issue_no_health.title)
        end
      end

      describe 'negated health only' do
        it 'excludes work items with specified health status' do
          select_tokens 'Health', '!=', 'On track', submit: true

          expect(page).to have_link(issue_needs_attention.title)
          expect(page).to have_link(issue_at_risk.title)
          expect(page).to have_link(issue_no_health.title)
          expect(page).not_to have_link(issue_on_track.title)
        end
      end

      context 'when issuable health status feature is not available' do
        let(:licensed_features) { super().merge(issuable_health_status: false) }

        it 'does not show health filter token' do
          click_filtered_search_bar

          expect(page).not_to have_css('[data-testid="filtered-search-token-segment"]', text: 'Health')
        end
      end
    end

    describe 'status' do
      before do
        visit project_work_items_path(project)
      end

      describe 'behavior' do
        it 'loads all the statuses when opened' do
          select_tokens 'Status'

          # Expect default system defined statuses
          expect_suggestion_count 5
        end
      end

      describe 'only status' do
        it 'filters work items by in progress status' do
          select_tokens 'Status', 'In progress', submit: true

          expect(page).to have_work_item_count(0)
        end

        it 'filters work items by to do status' do
          select_tokens 'Status', 'To do', submit: true

          expect(page).to have_work_item_count(15)
        end
      end

      context 'when status feature is not available' do
        let(:licensed_features) { super().merge(work_item_status: false) }

        it 'does not show status filter token' do
          click_filtered_search_bar

          expect(page).not_to have_css('[data-testid="filtered-search-token-segment"]', text: 'Status')
        end
      end
    end

    describe 'iteration' do
      before do
        visit project_work_items_path(project)
      end

      describe 'behaviour' do
        it 'loads all the iterations when opened' do
          select_tokens 'Iteration', '='
          within_testid('filtered-search-input') do
            expect(page).to have_text('Any')
            expect(page).to have_text('Current')
            expect(page).to have_text('None')
          end
        end

        context 'with multiple cadences' do
          it 'shows iterations grouped by cadence' do
            select_tokens 'Iteration', '='
            within_testid('filtered-search-input') do
              expect(page).to have_text(iteration_cadence.title)
              expect(page).to have_text(iteration_cadence_2.title)

              expect(page).to have_text('Iteration 1')
              expect(page).to have_text('Iteration 2')
              expect(page).to have_text('Sprint Alpha')
            end
          end
        end
      end

      describe 'only iteration' do
        it 'filters work items by specified iteration' do
          select_tokens 'Iteration', '=', 'Iteration 1', submit: true

          expect(page).to have_work_item_count(1)
          expect(page).to have_link(issue_with_iteration_1.title)
        end

        it 'filters work items by iteration period format' do
          select_tokens 'Iteration', '=', iteration_period(iteration_1, use_thin_space: false), submit: true
          expect(page).to have_work_item_count(1)
          expect(page).to have_link(issue_with_iteration_1.title)
          expect(page).not_to have_link(issue_with_iteration_2.title)
          expect(page).not_to have_link(issue_with_current_iteration.title)
          expect(page).not_to have_link(issue_without_iteration.title)
        end
      end

      describe 'current iteration' do
        it 'filters work items by Current iteration keyword' do
          select_tokens 'Iteration', '=', 'Current', submit: true
          expect(page).to have_work_item_count(1)
          expect(page).to have_link(issue_with_current_iteration.title)
          expect(page).not_to have_link(issue_with_iteration_1.title)
          expect(page).not_to have_link(issue_with_iteration_2.title)
          expect(page).not_to have_link(issue_without_iteration.title)
        end
      end

      describe 'iteration wildcards' do
        it 'filters work items by None iteration' do
          select_tokens 'Iteration', '=', 'None', submit: true

          expect(page).to have_link(issue_without_iteration.title)
          expect(page).not_to have_link(issue_with_iteration_1.title)
          expect(page).not_to have_link(issue_with_iteration_2.title)
        end

        it 'filters work items by Any iteration' do
          select_tokens 'Iteration', '=', 'Any', submit: true

          expect(page).to have_work_item_count(4)
          expect(page).to have_link(issue_with_iteration_1.title)
          expect(page).to have_link(issue_with_iteration_2.title)
          expect(page).to have_link(issue_with_iteration_from_cadence_2.title)
          expect(page).not_to have_link(issue_without_iteration.title)
        end
      end

      describe 'negated iteration only' do
        it 'excludes work items with specified iteration' do
          select_tokens 'Iteration', '!=', 'Iteration 1', submit: true

          expect(page).to have_link(issue_with_iteration_2.title)
          expect(page).to have_link(issue_without_iteration.title)
          expect(page).not_to have_link(issue_with_iteration_1.title)
        end

        it 'excludes work items with Current iteration' do
          select_tokens 'Iteration', '!=', 'Current', submit: true
          expect(page).to have_link(issue_with_iteration_1.title)
          expect(page).to have_link(issue_with_iteration_2.title)
          expect(page).to have_link(issue_without_iteration.title)
          expect(page).not_to have_link(issue_with_current_iteration.title)
        end
      end

      context 'when iterations feature is not available' do
        let(:licensed_features) { super().merge(iterations: false) }

        it 'does not show iteration filter token' do
          click_filtered_search_bar

          expect(page).not_to have_css('[data-testid="filtered-search-token-segment"]', text: 'Iteration')
        end
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
