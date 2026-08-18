# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project issue boards', :js, feature_category: :planning_views do
  let_it_be(:user) { create(:user) }

  let(:project) { create(:project, :public) }
  let!(:board) { create(:board, project: project) }
  let(:milestone) { create(:milestone, title: "v2.2", project: project) }
  let!(:board_with_milestone) { create(:board, project: project, milestone: milestone) }

  context 'with group and reporter' do
    let(:group) { create(:group) }
    let(:project) { create(:project, :public, namespace: group) }

    before do
      project.add_maintainer(user)
      group.add_reporter(user)
      sign_in(user)
    end

    it 'can edit board name' do
      visit_board_page

      board_name = board.name
      new_board_name = board_name + '-Test'

      find_by_testid('boards-config-button').click
      fill_in 'board-new-name', with: new_board_name
      click_button 'Save changes'

      expect(page).to have_content new_board_name
    end
  end

  context 'swimlanes dropdown' do
    context 'license feature on' do
      before do
        stub_licensed_features(swimlanes: true)
      end

      it 'does not show Epic swimlanes toggle when user is not logged in' do
        visit_board_page

        expect(page).to have_css('.filtered-search-block')
        page.find("[data-testid='board-options-dropdown'] button").click
        expect(page).not_to have_css('[data-testid="epic-swimlanes-toggle-item"]')
      end

      it 'shows Epic swimlanes toggle when user is logged in' do
        sign_in(user)
        visit_board_page

        page.find("[data-testid='board-options-dropdown'] button").click
        expect(page).to have_css('[data-testid="epic-swimlanes-toggle-item"]')
      end
    end

    context 'license feature off' do
      before do
        stub_licensed_features(swimlanes: false)
      end

      it 'does not show Epic swimlanes toggle when user is not logged in' do
        visit_board_page

        expect(page).to have_css('.filtered-search-block')

        page.find("[data-testid='board-options-dropdown'] button").click
        expect(page).not_to have_css('[data-testid="epic-swimlanes-toggle-item"]')
      end

      it 'does not show Epic swimlanes toggle when user is logged in' do
        sign_in(user)
        visit_board_page

        expect(page).to have_css('.filtered-search-block')

        page.find("[data-testid='board-options-dropdown'] button").click
        expect(page).not_to have_css('[data-testid="epic-swimlanes-toggle-item"]')
      end
    end
  end

  context 'total weight' do
    let!(:label) { create(:label, project: project, name: 'Label 1') }
    let!(:list) { create(:list, board: board, label: label, position: 0) }
    let!(:issue) { create(:issue, project: project, weight: 3, relative_position: 2) }
    let!(:issue_2) { create(:issue, project: project, weight: 2, relative_position: 1) }
    let!(:issue_3) { create(:issue, project: project, relative_position: 3) }

    before do
      project.add_developer(user)
      sign_in(user)
      visit_board_page
    end

    it 'shows total weight for backlog' do
      backlog = board.lists.first

      expect(list_weight_badge(backlog)).to have_content('5')
    end

    it 'updates weight when moving to list',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/2980' do
      from = board.lists.first
      to = list

      expect(list_weight_badge(from)).to have_content('3 5', exact: true)
      expect(list_weight_badge(to)).to have_content('0 0', exact: true)

      lists = all('.board-list')
      item = lists.at(0).find('.board-card:nth-child(1)')
      item.drag_to(lists.at(1))

      expect(card_weight_badge(from)).to have_content('3')
      expect(card_weight_badge(to)).to have_content('2')
      expect(list_weight_badge(from)).to have_content('2 3', exact: true)
      expect(list_weight_badge(to)).to have_content('1 2', exact: true)
    end

    it 'maintains weight if null when moving to list',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/6600' do
      from = board.lists.first
      to = list

      lists = all('.board-list')
      item = lists.at(0).all('.board-card').at(1)
      item.drag_to(lists.at(1))

      expect(card_weight_badge(from)).to have_content('2')
      expect(card_weight_badge(to)).to have_content('3')
    end

    context 'unlicensed' do
      before do
        stub_licensed_features(issue_weights: false)
        visit_board_page
      end

      it 'hides weight' do
        expect(page).not_to have_text('3 issues')

        backlog = board.lists.first
        list_weight_badge(backlog).hover

        expect(page).to have_text('3 issues')
      end
    end
  end

  context 'list header' do
    let(:max_issue_count) { 2 }
    let!(:label) { create(:label, project: project, name: 'Label 2') }
    let!(:list) { create(:list, board: board, label: label, position: 0, max_issue_count: max_issue_count) }
    let!(:issue) { create(:issue, project: project, labels: [label]) }

    before do
      project.add_developer(user)
      sign_in(user)
      visit_board_page
    end

    context 'When FF is turned on' do
      context 'when max issue count is set' do
        let(:total_development_issues) { "1" }

        it 'displays issue and max issue size' do
          page.within("[data-testid='board-list']:nth-child(2)") do
            page.within("[data-testid='item-count'] ") do
              expect(find_by_testid('board-items-count')).to have_text(total_development_issues)
              expect(page.find('.max-issue-size')).to have_text(max_issue_count)
            end
          end
        end
      end
    end
  end

  context 'list settings' do
    before do
      project.add_developer(user)
      sign_in(user)
    end

    context 'when license is available' do
      let!(:label) { create(:label, project: project, name: 'Brount') }
      let!(:list) { create(:list, board: board, label: label, position: 1) }

      before do
        stub_licensed_features(wip_limits: true)
        visit_board_page
      end

      it 'shows the list settings button' do
        page.within(find("[data-testid='board-list']:nth-child(2)")) do
          expect(page).to have_selector(:button, "Edit list settings")
        end
        expect(page).not_to have_selector(".js-board-settings-sidebar")
      end

      context 'when settings button is clicked' do
        it 'shows the board list settings sidebar' do
          page.within(find("[data-testid='board-list']:nth-child(2)")) do
            click_button('Edit list settings')
          end

          expect(page.find('.js-board-settings-sidebar').find('.gl-label-text')).to have_text("Brount")
        end
      end

      context 'when boards setting sidebar is open' do
        before do
          page.within(find("[data-testid='board-list']:nth-child(2)")) do
            click_button('Edit list settings')
          end
        end

        context "when user clicks Remove Limit" do
          before do
            max_issue_count = 2
            page.within(find('.js-board-settings-sidebar')) do
              click_button("Edit")

              find('input').set(max_issue_count)
            end

            click_button _('Apply')

            wait_for_requests
          end

          it "sets max issue count to zero" do
            expect(page).to have_button(_('Remove limit'), disabled: false, wait: 5)
            click_button _('Remove limit')

            wait_for_requests

            expect(find_by_testid('wip-limit')).to have_text("None")
          end
        end

        context 'when the user is editing a wip limit and clicks close' do
          it 'does not update the max issue count wip limit' do
            max_issue_count = 3
            page.within(find('.js-board-settings-sidebar')) do
              click_button("Edit")

              find('input').set(max_issue_count)
            end
            # Danger: coupling to gitlab-ui class name for close.
            # Change when https://gitlab.com/gitlab-org/gitlab-ui/issues/578 is resolved
            find('.gl-drawer-close-button').click

            wait_for_requests

            page.within(find("[data-testid='board-list']:nth-child(2)")) do
              click_button('Edit list settings')
            end

            expect(find_by_testid('wip-limit')).not_to have_text(max_issue_count)
          end
        end

        context "when user off clicks" do
          it 'does not update the max issue count wip limit and remains in edit mode' do
            max_issue_count = 2
            page.within(find('.js-board-settings-sidebar')) do
              click_button("Edit")
              find('input').set(max_issue_count)
            end

            find('body').click

            wait_for_requests

            page.within(find('.js-board-settings-sidebar')) do
              expect(page).to have_selector('input', visible: :visible)
            end
          end

          context "When user sets max issue count to 0 and off clicks" do
            it 'does not update the max issue count wip limit and remains in edit mode' do
              max_issue_count = 0
              page.within(find('.js-board-settings-sidebar')) do
                click_button("Edit")
                find('input').set(max_issue_count)
              end

              find('body').click

              wait_for_requests

              page.within(find('.js-board-settings-sidebar')) do
                expect(page).to have_selector('input', visible: :visible)
              end
            end
          end
        end

        context "when user hits enter" do
          it 'updates the max issue count wip limit' do
            page.within(find('.js-board-settings-sidebar')) do
              click_button("Edit")

              find('input').set(1).native.send_keys(:return)
            end

            wait_for_requests

            expect(find_by_testid('wip-limit')).to have_text(1)
          end
        end
      end
    end

    context 'when license is not available' do
      before do
        stub_licensed_features(wip_limits: false)
        visit project_boards_path(project)
      end

      it 'does not show the list settings button' do
        expect(page).to have_no_selector(:button, "Edit list settings")
        expect(page).not_to have_selector(".js-board-settings-sidebar")
      end
    end
  end

  context 'blocking issues' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:issue1) { create(:issue, project: project, title: 'Blocked issue') }
    let_it_be(:issue2, freeze: false) { create(:issue, project: project, title: 'Blocking issue') }

    before_all do
      create(:issue_link, source: issue2, target: issue1, link_type: IssueLink::TYPE_BLOCKS)
      project.add_developer(user)
    end

    before do
      sign_in(user)
      visit_board_page
    end

    it 'displays blocked icon on blocked issue card displayed info on hover' do
      page.within(find('[data-testid="board-list"]:nth-child(1)')) do
        page.within(first('.board-card')) do
          expect(page).to have_content(issue1.title)
          expect(page).to have_selector('[data-testid="relationship-blocked-by-icon"]')

          find_by_testid('relationship-blocked-by-icon').hover
        end
      end

      page.within(find('.gl-popover')) do
        expect(page).to have_content('blocked by')
        expect(page).to have_content(issue2.title)
      end
    end
  end

  def list_weight_badge(list)
    within("[data-testid='board-list'][data-list-id='gid://gitlab/List/#{list.id}']") do
      find_by_testid('issue-count-badge')
    end
  end

  def card_weight_badge(list)
    within("[data-testid='board-list'][data-list-id='gid://gitlab/List/#{list.id}']") do
      find_by_testid('board-card-weight-title')
    end
  end

  def visit_board_page
    visit project_boards_path(project)
    wait_for_requests
  end
end
