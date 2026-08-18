# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User adds milestone/iterations/status lists', :js, :aggregate_failures, feature_category: :planning_views do
  include Features::IterationHelpers

  let_it_be(:group) { create(:group, :nested) }
  let_it_be(:root_group) { group.root_ancestor }
  let_it_be_with_reload(:project) { create(:project, :public, namespace: group) }
  let_it_be(:group_board) { create(:board, group: group) }
  let_it_be(:project_board) { create(:board, project: project) }
  let_it_be_with_reload(:user) { create(:user, maintainer_of: project, owner_of: group) }

  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }
  let_it_be(:system_defined_todo_status) { build(:work_item_system_defined_status, :to_do) }

  let_it_be(:issue_with_milestone) { create(:issue, project: project, milestone: milestone) }
  let_it_be_with_reload(:issue_with_assignee) { create(:issue, project: project, assignees: [user]) }
  let_it_be(:issue_with_iteration) { create(:issue, project: project, iteration: iteration) }
  let_it_be(:issue_with_system_defined_status) do
    create(:work_item, project: project, system_defined_status_id: system_defined_todo_status.id)
  end

  where(:board_type) do
    [[:project], [:group]]
  end

  with_them do
    before do
      stub_licensed_features(
        board_milestone_lists: true,
        board_assignee_lists: true,
        board_iteration_lists: true,
        board_status_lists: true,
        work_item_status: true
      )
      sign_in(user)

      case board_type
      when :project
        visit project_board_path(project, project_board)
      when :group
        visit group_board_path(group, group_board)
      end

      wait_for_all_requests
    end

    it 'creates milestone column' do
      add_list('Milestone', milestone.title)

      expect(page).to have_selector('.board', text: milestone.title)
      expect(find('[data-testid="board-list"]:nth-child(2) .board-card')).to have_content(issue_with_milestone.title)
    end

    it 'creates assignee column' do
      add_list('Assignee', user.name)

      expect(page).to have_selector('.board', text: user.name)
      expect(find('[data-testid="board-list"]:nth-child(2) .board-card')).to have_content(issue_with_assignee.title)
    end

    it 'creates iteration column' do
      add_list('Iteration', iteration_period(iteration, use_thin_space: false))

      expect(page).to have_selector('.board', text: iteration.display_text)
      expect(find('[data-testid="board-list"]:nth-child(2) .board-card'))
        .to have_content(issue_with_iteration.title)
    end

    it 'creates status column for system defined status' do
      add_list('Status', system_defined_todo_status.name)

      expect(page).to have_selector('.board', text: system_defined_todo_status.name)
      expect(find('[data-testid="board-list"]:nth-child(2) .board-card:nth-child(4)'))
        .to have_content(issue_with_system_defined_status.title)
    end

    context 'with custom statuses' do
      let_it_be(:custom_status) do
        create(:work_item_custom_status, :to_do, name: "Custom to do", namespace: root_group)
      end

      let_it_be(:custom_lifecycle) do
        create(:work_item_custom_lifecycle, default_open_status: custom_status, namespace: root_group)
      end

      let!(:type_custom_lifecycle) do
        create(:work_item_type_custom_lifecycle,
          lifecycle: custom_lifecycle,
          work_item_type: build(:work_item_system_defined_type, :issue),
          namespace: root_group
        )
      end

      let_it_be(:issue_with_custom_status) do
        create(:work_item, project: project, custom_status_id: custom_status.id)
      end

      it 'creates status column for custom status' do
        type_custom_lifecycle

        page.refresh

        add_list('Status', custom_status.name)

        expect(page).to have_selector('.board', text: custom_status.name)
        expect(find('[data-testid="board-list"]:nth-child(2) .board-card:nth-child(5)'))
          .to have_content(issue_with_custom_status.title)
      end
    end
  end

  describe 'without a license' do
    before do
      stub_licensed_features(
        board_milestone_lists: false,
        board_assignee_lists: false,
        board_iteration_lists: false,
        board_status_lists: false,
        work_item_status: false
      )

      sign_in(user)

      visit project_board_path(project, project_board)

      wait_for_all_requests
    end

    it 'does not show other list types', :aggregate_failures do
      click_button 'New list'
      wait_for_all_requests

      within_testid('board-add-new-column') do
        expect(page).not_to have_text('Iteration')
        expect(page).not_to have_text('Assignee')
        expect(page).not_to have_text('Milestone')
        expect(page).not_to have_text('Status')
      end
    end
  end

  def add_list(list_type, title)
    click_button 'New list'
    wait_for_all_requests

    page.choose(list_type)

    find_button("Select a").click

    within_testid('base-dropdown-menu') do
      find('label', text: title).click
    end

    click_button 'Add to board'

    wait_for_all_requests
  end
end
