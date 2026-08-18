# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'epics swimlanes filtering', :js, feature_category: :planning_views do
  include BoardHelpers
  include GlFilteredSearchHelpers

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:user2)   { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project, freeze: false) { create(:project, :public, group: group, maintainers: [user, user2]) }
  let_it_be(:board) { create(:board, project: project) }

  let_it_be(:milestone) { create(:milestone, project: project) }

  let_it_be(:planning, freeze: false) { create(:label, project: project, name: 'Planning', description: 'Test') }
  let_it_be(:development) { create(:label, project: project, name: 'Development') }
  let_it_be(:testing)     { create(:label, project: project, name: 'Testing') }
  let_it_be(:backlog)     { create(:label, project: project, name: 'Backlog') }
  let_it_be(:closed)      { create(:label, project: project, name: 'Closed') }
  let_it_be(:list1)       { create(:list, board: board, label: planning, position: 0) }
  let_it_be(:list2)       { create(:list, board: board, label: development, position: 1) }

  let_it_be(:confidential_issue) { create(:labeled_issue, :confidential, project: project, author: user, labels: [planning], relative_position: 9) }
  let_it_be(:issue1, freeze: false) { create(:labeled_issue, project: project, title: 'aaa', description: '111', assignees: [user], labels: [planning], relative_position: 8) }
  let_it_be(:issue2) { create(:labeled_issue, project: project, title: 'bbb', description: '222', author: user2, labels: [planning], relative_position: 7) }
  let_it_be(:issue3) { create(:labeled_issue, project: project, title: 'ccc', description: '333', labels: [planning, testing], relative_position: 6) }
  let_it_be(:issue4) { create(:labeled_issue, project: project, title: 'ddd', description: '444', labels: [planning], relative_position: 5) }
  let_it_be(:issue5) { create(:labeled_issue, project: project, title: 'eee', description: '555', labels: [planning], milestone: milestone, relative_position: 4) }
  let_it_be(:issue6) { create(:labeled_issue, project: project, title: 'fff', description: '666', labels: [planning, development], relative_position: 3) }
  let_it_be(:issue7) { create(:labeled_issue, project: project, title: 'ggg', description: '777', labels: [development], relative_position: 2) }
  let_it_be(:issue8) { create(:closed_issue, project: project, title: 'hhh', description: '888') }

  let(:all_issues) { [confidential_issue, issue1, issue2, issue3, issue4, issue5, issue6, issue7, issue8] }

  context 'filtering' do
    before do
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(200)
      stub_licensed_features(epics: true, swimlanes: true)

      sign_in(user)
      visit_board_page

      load_epic_swimlanes

      load_unassigned_issues

      wait_for_all_issues
    end

    it 'filters by author' do
      set_filter("author", user2.username)
      click_filter_button(user2.username)
      submit_filter

      wait_for_board_cards(2, 1)
      wait_for_empty_boards(3..4)
    end

    it 'filters by assignee' do
      set_filter("assignee", user.username)
      click_filter_button(user.username)
      submit_filter

      wait_for_board_cards(2, 1)
      wait_for_empty_boards(3..4)
    end

    it 'filters by milestone' do
      set_filter("milestone", "\"#{milestone.title}")
      click_filter_button(milestone.title)
      submit_filter

      wait_for_board_cards(2, 1)
      wait_for_board_cards(3, 0)
      wait_for_board_cards(4, 0)
    end

    it 'filters by label' do
      set_filter("label", testing.title)
      click_filter_button(testing.title)
      submit_filter

      wait_for_board_cards(2, 1)
      wait_for_empty_boards(3..4)
    end
  end

  def visit_board_page
    visit project_boards_path(project)
    wait_for_all_issues
  end

  def wait_for_board_cards(board_number, expected_cards)
    page.within(find(".board-swimlanes-headers .board:nth-child(#{board_number})")) do
      expect(page.find('.board-header')).to have_content(expected_cards.to_s)
    end

    page.within(find("[data-testid='board-lane-unassigned-issues'] .board:nth-child(#{board_number})")) do
      expect(page).to have_selector('.board-card', count: expected_cards)
    end
  end

  def wait_for_empty_boards(board_numbers)
    board_numbers.each do |board|
      wait_for_board_cards(board, 0)
    end
  end

  def wait_for_all_issues
    all_issues.each do |i|
      page.has_content?(i.title)
    end
  end

  def set_filter(type, _text)
    gl_filtered_search_set_input("#{type}:")
    gl_filtered_search_first_suggestion.click
  end

  def submit_filter
    click_button 'Search'
  end

  def click_filter_button(text)
    page.within('.gl-filtered-search-suggestion-list') do
      expect(page).to have_button(text)

      click_on text
    end
  end
end
