# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'epic boards', :js, feature_category: :planning_views do
  include ListboxHelpers
  # please do not switch below `let!` to `let_it_be` due to potential flakiness.
  # see https://gitlab.com/gitlab-org/gitlab/-/merge_requests/122712#note_1420351482
  let!(:user)        { create(:user) }
  let!(:group)       { create(:group, :public) }
  let!(:epic_board)  { create(:epic_board, group: group, name: "EPIC BOARD 1") }
  let!(:epic_board2) { create(:epic_board, group: group, name: "EPIC BOARD 2") }

  context 'multiple epic boards' do
    before do
      stub_licensed_features(epics: true)

      group.add_maintainer(user)
      sign_in(user)
      visit_epic_boards_page
    end

    it 'shows current epic board name' do
      page.within('.boards-switcher') do
        expect(page).to have_content(epic_board.name)
      end
    end

    it 'shows a list of epic boards',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/11463' do
      in_boards_switcher_dropdown do
        expect(page).to have_content(epic_board.name)
        expect(page).to have_content(epic_board2.name)
      end
    end

    it 'switches current epic board',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/18806' do
      in_boards_switcher_dropdown do
        select_listbox_item(epic_board2.name)
      end

      wait_for_requests

      page.within('.boards-switcher') do
        expect(page).to have_content(epic_board2.name)
      end
    end

    it 'creates new epic board without detailed configuration' do
      in_boards_switcher_dropdown do
        click_button 'Create new board'
      end

      fill_in 'board-new-name', with: 'This is a new board'
      click_button 'Create board'
      wait_for_requests

      expect(page).to have_button('This is a new board')
    end

    it 'deletes an epic board',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/18837' do
      in_boards_switcher_dropdown do
        aggregate_failures do
          expect(page).to have_content(epic_board.name)
          expect(page).to have_content(epic_board2.name)
        end
      end

      find_by_testid('boards-config-button').click
      find_by_testid('delete-board-button').click
      find_by_testid('save-changes-button').click

      wait_for_requests

      in_boards_switcher_dropdown do
        aggregate_failures do
          expect(page).not_to have_content(epic_board.name)
          expect(page).to have_content(epic_board2.name)
        end
      end
    end
  end

  def visit_epic_boards_page
    visit group_epic_boards_path(group)
    wait_for_requests
  end

  def in_boards_switcher_dropdown
    find('.boards-switcher').click

    wait_for_requests

    dropdown_selector = '[data-testid="boards-selector"] .gl-new-dropdown'
    page.within(dropdown_selector) do
      yield
    end
  end
end
