# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'epic boards', :sidekiq_inline, :js, :saas, feature_category: :planning_views do
  include MobileHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, :public, plan: :premium_plan) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:epic_board) { create(:epic_board, group: group) }
  let_it_be(:label) { create(:group_label, group: group, name: 'Label1') }
  let_it_be(:label2) { create(:group_label, group: group, name: 'Label2') }
  let_it_be(:label_list) { create(:epic_list, epic_board: epic_board, label: label, position: 0) }
  let_it_be(:backlog_list) { create(:epic_list, epic_board: epic_board, list_type: :backlog) }
  let_it_be(:closed_list) { create(:epic_list, epic_board: epic_board, list_type: :closed) }

  let_it_be(:issue_with_weight) { create(:issue, project: project, weight: 2) }

  let_it_be(:epic1) { create(:epic, group: group, labels: [label], author: user, title: 'Epic1') }
  let_it_be(:epic2) { create(:epic, group: group, title: 'Epic2') }
  let_it_be(:epic3) { create(:epic, group: group, labels: [label2], title: 'Epic3') }

  let!(:epic_issue) { create(:epic_issue, epic: epic3, issue: issue_with_weight) }

  let(:edit_board) { find_by_testid('boards-config-button') }
  let(:view_scope) { find_by_testid('boards-config-button') }

  context 'display epics in board' do
    before do
      stub_licensed_features(epics: true)
      group.add_maintainer(user)
      sign_in(user)
    end

    context 'with agentic chat enabled',
      quarantine: 'https://gitlab.com/gitlab-org/quality/analytics/ci-health-incidents/-/work_items/859' do
      include_context 'with duo features enabled and agentic chat available for group on SaaS'

      before do
        stub_licensed_features(epics: true, agentic_chat: true)
      end

      it_behaves_like 'user can use agentic chat' do
        subject { group_epic_boards_path(group) }

        let(:container) { group }
        let(:entity) { epic1 }
      end

      it_behaves_like 'user can navigate AI panel using navigation rail' do
        subject { group_epic_boards_path(group) }
      end
    end

    context 'default' do
      before do
        visit_epic_boards_page
      end

      it 'displays default lists and a label list' do
        lists = %w[Open Label1 Closed]

        expect(page).to have_selector('.board-header', count: 3)

        page.all('.board-header').each_with_index do |list, i|
          expect(list.find('.board-title')).to have_content(lists[i])
        end
      end

      it 'displays two epics in Open list' do
        expect(list_header(backlog_list)).to have_content('2')

        page.within("[data-board-type='backlog']") do
          expect(page).to have_selector('.board-card', count: 2)
          page.within(first('.board-card')) do
            expect(page).to have_content('Epic3')
          end

          page.within('.board-card:nth-child(2)') do
            expect(page).to have_content('Epic2')
          end
        end
      end

      it 'displays one epic in Label list' do
        expect(list_header(label_list)).to have_content('1')

        page.within("[data-board-type='label']") do
          expect(page).to have_selector('.board-card', count: 1)
          page.within(first('.board-card')) do
            expect(page).to have_content('Epic1')
          end
        end
      end

      it 'creates new column for label containing labeled epic' do
        click_button 'New list'
        find_button 'Select a label'

        click_button 'Select a label'

        within_testid('board-add-new-column') do
          find('label', text: label2.title).click
        end

        click_button 'Add to board'

        expect(page).to have_selector('.board', text: label2.title)
        expect(find('[data-testid="board-list"]:nth-child(3) .board-card')).to have_content(epic3.title)
      end

      it 'moves to the bottom of another list' do
        expect(find_board_list(1)).to have_content(epic3.title)

        drag(list_from_index: 0, list_to_index: 1, to_index: 1)

        expect(find_board_list(1)).not_to have_content(epic3.title)
        page.within(find_board_list(2)) do
          expect(page).to have_css('.board-card:nth-child(2)', text: epic3.title)
        end
      end

      it 'moves to the top of another list' do
        expect(find_board_list(1)).to have_content(epic3.title)

        drag(list_from_index: 0, list_to_index: 1, to_index: 0)

        expect(find_board_list(1)).not_to have_content(epic3.title)

        page.within(find_board_list(2)) do
          expect(page).to have_css('.board-card:first-child', text: epic3.title)
        end
      end
    end

    context 'Moving epics' do
      before do
        visit_epic_boards_page
      end

      it 'moving updates epics count and weight of both lists', :aggregate_failures do
        expect(find_board_list(1)).to have_content(epic3.title)

        page.within(find_board_list(1)) do
          within_testid('board-list-header') do
            expect(find_by_testid('item-count')).to have_content('2')
            expect(find_by_testid('weight')).to have_content(issue_with_weight.weight)
          end
        end

        page.within(find_board_list(2)) do
          within_testid('board-list-header') do
            expect(find_by_testid('item-count')).to have_content('1')
            expect(find_by_testid('weight')).to have_content('0')
          end
        end

        drag(list_from_index: 0, list_to_index: 1, to_index: 0)

        expect(find_board_list(1)).not_to have_content(epic3.title)

        page.within(find_board_list(2)) do
          within_testid('board-list-header') do
            expect(find_by_testid('item-count')).to have_content('2')
            expect(find_by_testid('weight')).to have_content(issue_with_weight.weight)
          end
        end

        page.within(find_board_list(1)) do
          within_testid('board-list-header') do
            expect(find_by_testid('item-count')).to have_content('1')
            expect(find_by_testid('weight')).to have_content('0')
          end
        end
      end
    end

    context 'ordering in list using move to position' do
      let_it_be(:epic4) { create(:epic, group: group, title: 'Epic4') }
      let(:move_to_position) { find_by_testid('board-move-to-position') }

      before do
        visit_epic_boards_page
      end

      it 'moves to end of list' do
        page.within(find('[data-testid="board-list"]:nth-child(1)')) do
          first_card = first('.board-card')
          first_card_title = first_card.text.split("\n").first

          first_card.hover
          move_to_position.click

          click_button 'Move to end of list'

          expect(page).to have_css('.board-card:last-child', text: first_card_title)
        end
      end

      it 'moves to start of list' do
        page.within(find('[data-testid="board-list"]:nth-child(1)')) do
          last_card = find('.board-card:last-child')
          last_card_title = last_card.text.split("\n").first

          last_card.hover
          move_to_position.click

          click_button 'Move to start of list'

          expect(page).to have_css('.board-card:first-child', text: last_card_title)
        end
      end
    end

    context 'lists' do
      let_it_be(:label_list2) { create(:epic_list, epic_board: epic_board, label: label2, position: 1) }

      before do
        visit_epic_boards_page
      end

      it 'changes position of list' do
        expect(find_board_list(2)).to have_content(label.title)
        expect(find_board_list(3)).to have_content(label2.title)

        headers = all('.board-header')
        from_item = headers.at(2)
        to_item = headers.at(1)
        from_item.drag_to(to_item)

        expect(find_board_list(2)).to have_content(label2.title)
        expect(find_board_list(3)).to have_content(label.title)

        # Make sure list positions are preserved after a reload
        visit_epic_boards_page

        expect(find_board_list(2)).to have_content(label2.title)
        expect(find_board_list(3)).to have_content(label.title)
      end

      it 'dragging does not duplicate list' do
        selector = '[data-testid="board-list"]:not(.is-ghost) .board-header'
        expect(page).to have_selector(selector, text: label.title, count: 1)

        headers = all('.board-header')
        from_item = headers.at(2)
        to_item = headers.at(1)
        from_item.drag_to(to_item)

        expect(page).to have_selector(selector, text: label.title, count: 1)
      end

      it 'allows user to delete list from list settings sidebar' do
        selector = '[data-testid="board-list-header"]'
        expect(page).to have_selector(selector, text: label.title, count: 1)

        # Ensure that all lists are loaded before trying to remove.
        # When a list is loaded, the sidebar and modal are dismissed, leading to a flaky spec
        expect(page).not_to have_testid('board_list_loading')

        page.within(find('[data-testid="board-list"]:nth-child(2)')) do
          click_button 'Edit list settings'
        end

        page.within('.gl-drawer-sidebar') do
          click_button('Remove list', match: :first)
        end

        page.within('.modal-dialog') do
          click_button('Remove list')
        end

        expect(page).not_to have_selector(selector, text: label.title)
      end
    end
  end

  context 'when user can admin epic boards' do
    before do
      stub_licensed_features(epics: true)
      group.add_maintainer(user)
      sign_in(user)
      visit_epic_boards_page
    end

    it "shows 'Create list' button" do
      expect(page).to have_selector('[data-testid="boards-create-list"]')
    end

    it 'creates board filtering by one label' do
      create_board_label(label.title)

      expect(page).to have_selector('.board-card', count: 1)
    end

    it 'adds label to board scope and filters epics' do
      expect(page).to have_content(epic_board.name)

      label_title = label.title

      update_board_label(label_title)

      aggregate_failures do
        expect(page).to have_selector('.board-card', count: 1)
        expect(page).to have_content('Epic1')
        expect(page).not_to have_content('Epic2')
        expect(page).not_to have_content('Epic3')
      end
    end
  end

  context 'when user cannot admin epic boards' do
    before do
      stub_licensed_features(epics: true)
      group.add_guest(user)
      sign_in(user)
      visit_epic_boards_page
    end

    it "does not show 'Create list'" do
      expect(page).not_to have_selector('[data-testid="boards-create-list"]')
    end

    it 'can view board scope' do
      view_scope.click

      page.within('.modal') do
        aggregate_failures do
          expect(find('.modal-header')).to have_content('Board configuration')
          expect(page).not_to have_content('Board name')
          expect(page).not_to have_link('Edit')
          expect(page).not_to have_button('Edit')
          expect(page).not_to have_button('Save')
          expect(page).not_to have_button('Cancel')
        end
      end
    end

    it 'does not show Remove list in list settings sidebar' do
      page.within(find('[data-testid="board-list"]:nth-child(2)')) do
        click_button 'Edit list settings'
      end

      expect(page).not_to have_button('Remove list')
    end
  end

  context 'filtered search' do
    before do
      stub_licensed_features(epics: true)

      group.add_guest(user)
      sign_in(user)
      visit_epic_boards_page
      page.has_content?(epic_board.name)

      # Focus on search field
      find_field('Search').click
    end

    it 'can select a Label in order to filter the board by not equals' do
      within_testid('epic-filtered-search') do
        click_button 'Label'
        click_button '!='
        click_button label.title

        find('input').native.send_keys(:return)
      end

      expect(list_header(label_list)).to have_content('0')
      expect(page).to have_content('Epic2')
      expect(page).to have_content('Epic3')
      expect(page).not_to have_content('Epic1')
    end

    it 'can select a Label in order to filter the board by equals' do
      within_testid('epic-filtered-search') do
        click_button 'Label'
        click_token_equals
        click_button label.title

        find('input').native.send_keys(:return)
      end

      expect(list_header(label_list)).to have_content('1')
      expect(page).to have_content('Epic1')
      expect(page).not_to have_content('Epic2')
      expect(page).not_to have_content('Epic3')
    end

    it 'can select an Author in order to filter the board by equals' do
      within_testid('epic-filtered-search') do
        click_button 'Author'
        click_token_equals
        click_button user.name

        find('input').native.send_keys(:return)
      end

      expect(list_header(label_list)).to have_content('1')
      expect(page).to have_content('Epic1')
      expect(page).not_to have_content('Epic2')
      expect(page).not_to have_content('Epic3')
    end

    it 'can select an Author in order to filter the board by not equals' do
      within_testid('epic-filtered-search') do
        click_button 'Author'
        click_button '!='
        click_button user.name

        find('input').native.send_keys(:return)
      end

      expect(list_header(label_list)).to have_content('0')
      expect(page).to have_content('Epic2')
      expect(page).to have_content('Epic3')
      expect(page).not_to have_content('Epic1')
    end

    it 'can search for an epic in the search bar' do
      fill_in 'Search', with: 'Epic 1'
      send_keys :enter, :enter

      expect(list_header(label_list)).to have_content('1')
      expect(page).to have_content('Epic1')
      expect(page).not_to have_content('Epic2')
      expect(page).not_to have_content('Epic3')
    end
  end

  context "when user is navigating via keyboard" do
    before do
      stub_licensed_features(epics: true)
      group.add_guest(user)
      sign_in(user)
      visit_epic_boards_page
    end

    it 'allows user to traverse cards forward and backward across board columns' do
      expect(page).not_to have_testid('board_list_loading')

      click_link(epic3.title, match: :first)
      send_keys :escape
      send_keys :right

      expect(page).to have_selector('.board-card-button[data-col-index="1"]', focused: true)

      send_keys :left

      expect(page).to have_selector('.board-card-button[data-col-index="0"]', focused: true)
    end
  end

  def visit_epic_boards_page
    visit group_epic_boards_path(group)
    expect(page).to have_selector('.board-header')
  end

  def list_header(list)
    find("[data-list-id='gid://gitlab/Boards::EpicList/#{list.id}'] .board-header")
  end

  def drag(selector: '.board-list', list_from_index: 0, from_index: 0, to_index: 0, list_to_index: 0)
    # ensure there is enough horizontal space for four lists
    resize_window(2000, 800)

    expect(page).not_to have_testid('board_list_loading')

    lists = all(selector)
    from_list = lists.at(list_from_index)
    from_item = from_list.all('.board-card').at(from_index)
    to_list = lists.at(list_to_index)

    to_item = to_list.all('.board-card').at(to_index).presence || to_list

    from_item.drag_to(to_item)
  end

  def click_value(filter, value)
    page.within(".#{filter}") do
      click_button 'Edit'

      if value.is_a?(Array)
        value.each { |value| click_link value }
      else
        click_on value
      end
    end
  end

  def click_on_create_new_board
    within_testid('boards-selector') do
      find_by_testid('boards-dropdown').find('button:not([aria-disabled="true"])').click
      find_button('Create new board')

      click_button 'Create new board'
    end
  end

  def create_board_label(label_title)
    create_board_scope('labels', label_title)
  end

  def create_board_scope(filter, value)
    click_on_create_new_board
    find('#board-new-name').set 'test'

    click_button 'Expand'

    click_value(filter, value)

    send_keys :escape

    click_button 'Create board'

    expect(page).to have_selector('.board-header')
  end

  def update_board_scope(filter, value)
    edit_board.click

    click_value(filter, value)

    send_keys :escape

    click_button 'Save changes'

    expect(page).not_to have_button('Save changes')
  end

  def update_board_label(label_title)
    update_board_scope('labels', label_title)
  end

  # This isnt the "best" matcher but because we have opts
  # != and = the find function returns both links when finding by =
  def click_token_equals
    first('button', text: '=').click
  end

  def find_board_list(board_number)
    find("[data-testid='board-list']:nth-child(#{board_number})")
  end
end
