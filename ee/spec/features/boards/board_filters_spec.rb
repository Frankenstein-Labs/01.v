# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Issue board filters', :js, feature_category: :planning_views do
  include FilteredSearchHelpers
  include Features::IterationHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:cadence_1) { create(:iterations_cadence, group: group) }
  let_it_be(:cadence_2) { create(:iterations_cadence, group: group) }
  let_it_be(:iteration) { create(:iteration, iterations_cadence: cadence_1, start_date: Time.zone.today) }
  let_it_be(:iteration_2) { create(:iteration, iterations_cadence: cadence_2) }
  let_it_be(:iteration_3) { create(:iteration, iterations_cadence: cadence_1) }
  let_it_be(:issue) do
    create(:issue, project: project, weight: 2, health_status: :on_track, title: "Some title")
  end

  let_it_be(:issue_2) { create(:issue, project: project, iteration: iteration, weight: 3, title: "Other title") }
  let_it_be(:issue_3) do
    create(:issue, project: project, health_status: :at_risk, title: "Third issue")
  end

  let_it_be(:issue_4) do
    create(:issue, project: project, iteration: iteration_2, title: "Fourth issue")
  end

  let_it_be(:epic_issue1) { create(:epic_issue, epic: epic, issue: issue, relative_position: 1) }

  shared_examples 'board filters by epic' do
    describe 'filters by epic' do
      it 'lists all epic options' do
        select_tokens('Epic', '=')
        expect_suggestion_count(3)
      end

      it 'loads all the epics when opened and submit one as filter', :aggregate_failures do
        expect_board_list_work_item_count(4)

        select_tokens('Epic', '=', epic.title, submit: true)

        expect_board_list_work_item_count(1)
        expect_board_list_to_contain(issue)
      end
    end
  end

  shared_examples 'board filters by iteration' do
    describe 'filters by iteration' do
      it 'list all iteration options' do
        select_tokens('Iteration', '=')

        # 3 base options: None, Any, Current
        # Cadence 1 group: Any, Current, + 2 iterations
        # Cadence 2 group: Any, Current, + 1 iteration
        expect_suggestion_count(10)
      end

      it 'loads all the iterations when opened and submit one as filter', :aggregate_failures do
        expect_board_list_work_item_count(4)

        select_tokens('Iteration', '=', iteration_period(iteration, use_thin_space: false), submit: true)

        expect_board_list_work_item_count(1)
        expect_board_list_to_contain(issue_2)
      end

      it 'loads all the iterations when filtering by Current iteration', :aggregate_failures do
        expect_board_list_work_item_count(4)
        select_tokens('Iteration', '=', 'Current', submit: true)
        expect_board_list_work_item_count(1)
        expect_board_list_to_contain(issue_2)
      end

      it 'excludes work items from a specific iteration when negating', :aggregate_failures do
        expect_board_list_work_item_count(4)
        select_tokens('Iteration', '!=', iteration_period(iteration, use_thin_space: false), submit: true)
        expect_board_list_work_item_count(3)
        expect_board_list_to_contain(issue)
        expect_board_list_to_contain(issue_3)
        expect_board_list_to_contain(issue_4)
        expect_board_list_to_not_contain(issue_2)
      end

      it 'excludes work items from Current iteration when negating', :aggregate_failures do
        expect_board_list_work_item_count(4)
        select_tokens('Iteration', '!=', 'Current', submit: true)
        expect_board_list_work_item_count(3)
        expect_board_list_to_contain(issue)
        expect_board_list_to_contain(issue_3)
        expect_board_list_to_contain(issue_4)
        expect_board_list_to_not_contain(issue_2)
      end

      context 'when iterations are not available' do
        before do
          stub_licensed_features(epics: true, iterations: false, issuable_health_status: true)
          visit page_path
          wait_for_requests
        end

        it 'does not show the iteration filter option' do
          click_filtered_search_bar
          expect_no_suggestion('Iteration')
        end
      end
    end
  end

  shared_examples 'board filters by weight' do
    describe 'filters by weight' do
      it 'list all weight options' do
        select_tokens('Weight', '=')

        expect_suggestion_count(23)
      end

      it 'loads all the weights when opened and submit one as filter', :aggregate_failures do
        expect_board_list_work_item_count(4)

        select_tokens('Weight', '=', '2', submit: true)

        expect_board_list_work_item_count(1)
        expect_board_list_to_contain(issue)
      end
    end
  end

  shared_examples 'board filters by health status' do
    describe 'filters by health status' do
      it 'lists all health statuses' do
        select_tokens('Health', '=')
        # None, Any, On track, Needs attention, At risk
        expect_suggestion_count(5)
      end

      it 'lists all negated health statuses' do
        select_tokens('Health', '!=')
        # On track, Needs attention, At risk
        expect_suggestion_count(3)
      end

      it 'loads only on track work items when opened and submit one as filter', :aggregate_failures do
        expect_board_list_work_item_count(4)

        select_tokens('Health', '=', 'On track', submit: true)

        expect_board_list_work_item_count(1)
        expect_board_list_to_contain(issue)
        expect_board_list_to_not_contain(issue_2)

        page.refresh

        expect_board_list_work_item_count(1)
        expect_board_list_to_contain(issue)
        expect_board_list_to_not_contain(issue_2)
      end

      it 'loads only issues with a health status that are not on track', :aggregate_failures,
        quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/17070' do
        expect_board_list_work_item_count(4)

        select_tokens('Health', '!=', 'On track', 'Health', '=', 'Any', submit: true)

        expect_board_list_work_item_count(1)
        expect_board_list_to_contain(issue_3)
        expect_board_list_to_not_contain(issue)

        page.refresh

        expect_board_list_work_item_count(1)
        expect_board_list_to_contain(issue_3)
        expect_board_list_to_not_contain(issue)
      end

      it 'loads only issues that have no health status', :aggregate_failures do
        expect_board_list_work_item_count(4)

        select_tokens('Health', '=', 'None', submit: true)

        expect_board_list_work_item_count(2)
        expect_board_list_to_contain(issue_2)
        expect_board_list_to_contain(issue_4)
        expect_board_list_to_not_contain(issue)
        expect_board_list_to_not_contain(issue_3)
      end
    end
  end

  shared_examples 'board combined filters' do
    describe 'combined filters' do
      it 'filters on multiple tokens' do
        expect_board_list_work_item_count(4)

        select_tokens('Health', '=', 'On track', 'Weight', '=', '2', 'Epic', '=', epic.title)
        send_keys 'Some title', :enter, :enter

        expect_board_list_work_item_count(1)
        expect_board_list_to_contain(issue)

        visit page_path
        wait_for_requests

        select_tokens('Health', '=', 'None', 'Weight', '!=', '2', 'Epic', '=', 'None', 'Iteration', '=',
          iteration_period(iteration, use_thin_space: false))
        send_keys 'Other title', :enter, :enter

        expect_board_list_work_item_count(1)
        expect_board_list_to_contain(issue_2)
      end
    end
  end

  shared_context 'with board setup' do
    before do
      stub_licensed_features(epics: true, iterations: true, issuable_health_status: true)
      visit page_path
      wait_for_requests
    end
  end

  context 'in project board' do
    let(:board) { create(:board, project: project) }
    let(:page_path) { project_board_path(project, board) }

    before_all do
      project.add_maintainer(user)
    end

    before do
      sign_in(user)
    end

    include_context 'with board setup'

    it_behaves_like 'board filters by epic'
    it_behaves_like 'board filters by iteration'
    it_behaves_like 'board filters by weight'
    it_behaves_like 'board filters by health status'
    it_behaves_like 'board combined filters'

    context 'when viewing list of iterations',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/5506' do
      before do
        visit page_path
        wait_for_requests
        select_tokens('Iteration', '=')
      end

      it 'shows cadence titles and iteration periods', :aggregate_failures do
        within '.gl-filtered-search-suggestion-list' do
          # cadence 1 grouping
          expect(page).to have_css('li:nth-child(7)', text: 'Any')
          expect(page).to have_css('li:nth-child(8)', text: 'Current')
          expect(page).to have_css('li:nth-child(9)', text: iteration_period(iteration_3, use_thin_space: false))
          expect(page).to have_css('li:nth-child(10)', text: iteration_period(iteration, use_thin_space: false))
          # cadence 2 grouping
          expect(page).to have_css('li:nth-child(12)', text: cadence_2.title)
          expect(page).to have_css('li:nth-child(13)', text: 'Any')
          expect(page).to have_css('li:nth-child(14)', text: 'Current')
          expect(page).to have_css('li:nth-child(15)', text: iteration_period(iteration_2, use_thin_space: false))
        end
      end
    end
  end

  context 'in group board' do
    let(:board) { create(:board, group: group) }
    let(:page_path) { group_board_path(group, board) }

    before_all do
      group.add_developer(user)
    end

    before do
      sign_in(user)
    end

    include_context 'with board setup'

    it_behaves_like 'board filters by epic'
    it_behaves_like 'board filters by iteration'
    it_behaves_like 'board filters by weight'
    it_behaves_like 'board filters by health status'
    it_behaves_like 'board combined filters'

    context 'when viewing list of iterations',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/17072' do
      before do
        visit page_path
        wait_for_requests
        select_tokens('Iteration', '=')
      end

      it 'shows cadence titles and iteration periods', :aggregate_failures do
        within '.gl-filtered-search-suggestion-list' do
          # cadence 1 grouping
          expect(page).to have_css('li:nth-child(7)', text: 'Any')
          expect(page).to have_css('li:nth-child(8)', text: 'Current')
          expect(page).to have_css('li:nth-child(9)', text: iteration_period(iteration_3, use_thin_space: false))
          expect(page).to have_css('li:nth-child(10)', text: iteration_period(iteration, use_thin_space: false))
          # cadence 2 grouping
          expect(page).to have_css('li:nth-child(12)', text: cadence_2.title)
          expect(page).to have_css('li:nth-child(13)', text: 'Any')
          expect(page).to have_css('li:nth-child(14)', text: 'Current')
          expect(page).to have_css('li:nth-child(15)', text: iteration_period(iteration_2, use_thin_space: false))
        end
      end
    end
  end

  def expect_board_list_work_item_count(count)
    expect(all('[data-testid="board-list"]')[0]).to have_selector('.board-card', count: count)
  end

  def expect_board_list_to_contain(issue)
    expect(page).to have_testid('board-card', text: issue.title)
  end

  def expect_board_list_to_not_contain(issue)
    expect(page).not_to have_testid('board-card', text: issue.title)
  end
end
