# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Related issues', :js, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project_empty_repo, :public) }
  let_it_be(:project_b) { create(:project_empty_repo, :public) }
  let_it_be(:project_unauthorized) { create(:project_empty_repo, :public) }
  let_it_be(:issue_a) { create(:issue, project: project) }
  let_it_be(:issue_b) { create(:issue, project: project) }
  let_it_be(:issue_c) { create(:issue, project: project) }
  let_it_be(:issue_d) { create(:issue, project: project) }
  let_it_be(:issue_project_b_a) { create(:issue, project: project_b) }
  let_it_be(:issue_project_unauthorized_a) { create(:issue, project: project_unauthorized) }

  context 'when user has permission to manage related issues' do
    before do
      project.add_maintainer(user)
      project_b.add_maintainer(user)
      sign_in(user)
    end

    context 'with "Related to", "Blocking", "Blocked by" groupings' do
      def add_linked_issue(issue, radio_input)
        find_by_testid('link-item-add-button').click
        fill_in 'Search existing items', with: issue.title
        click_button issue.title
        choose radio_input
        within_testid('link-work-item-form') do
          click_button 'Add'
        end
        expect(page).to have_link(issue.title)
      end

      before do
        visit project_issue_path(project, issue_a)
      end

      context 'when adding a "Related to" issue' do
        it 'shows the added issue with a "Related to" heading' do
          within_testid('work-item-relationships') do
            add_linked_issue(issue_b, "relates to")

            expect(page).to have_css('h3', text: 'Related to')
            expect(page).to have_link(issue_b.title)
            expect(page).to have_css('[data-testid="linked-items-count-badge"]', text: '1')
          end
        end
      end

      context 'when adding a "Blocking" issue' do
        it 'shows the added issue with a "Blocking" heading' do
          within_testid('work-item-relationships') do
            add_linked_issue(issue_b, "blocks")

            expect(page).to have_css('h3', text: 'Blocking')
            expect(page).to have_link(issue_b.title)
            expect(page).to have_css('[data-testid="linked-items-count-badge"]', text: '1')
          end
        end
      end

      context 'when adding an "Blocked by" issue' do
        it 'shows the added issue with a "Blocked by" heading' do
          within_testid('work-item-relationships') do
            add_linked_issue(issue_b, "is blocked by")

            expect(page).to have_css('h3', text: 'Blocked by')
            expect(page).to have_link(issue_b.title)
            expect(page).to have_css('[data-testid="linked-items-count-badge"]', text: '1')
          end
        end

        context 'when clicking the top `Close issue` button in the issue header', :aggregate_failures do
          it 'shows a modal to confirm closing the issue' do
            within_testid('work-item-relationships') do
              add_linked_issue(issue_b, "is blocked by")
            end

            click_button 'More actions', match: :first
            click_button 'Close issue', match: :first

            within('.modal-content', visible: true) do
              expect(page).to have_css('h2', text: 'Are you sure you want to close this blocked issue?')
              expect(page).to have_link("##{issue_b.iid}")

              click_button 'Yes, close issue'
            end

            expect(page).to have_css('.gl-badge', text: 'Closed')
            expect(page).not_to have_selector('.modal-content', visible: :visible)
          end
        end

        context 'when clicking the bottom `Close issue` button below the comment textarea', :aggregate_failures,
          quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/6924' do
          it 'shows a modal to confirm closing the issue' do
            within_testid('work-item-relationships') do
              add_linked_issue(issue_b, "is blocked by")
            end

            click_button 'Close issue'

            within('.modal-content', visible: true) do
              expect(page).to have_css('h2', text: 'Are you sure you want to close this blocked issue?')
              expect(page).to have_link("##{issue_b.iid}")

              click_button 'Yes, close issue'
            end

            expect(page).to have_css('.gl-badge', text: 'Closed')
            expect(page).not_to have_selector('.modal-content', visible: :visible)
          end
        end
      end

      context 'when adding "Related to", "Blocking", and "Blocked by" issues' do
        it 'shows all added issues and headings' do
          within_testid('work-item-relationships') do
            add_linked_issue(issue_b, "relates to")
            add_linked_issue(issue_c, "blocks")
            add_linked_issue(issue_d, "is blocked by")
          end

          within('[data-testid="work-item-linked-items-list"]:nth-child(1)') do
            expect(page).to have_css('h3', text: 'Blocking')
            expect(page).to have_link(issue_c.title)
          end
          within('[data-testid="work-item-linked-items-list"]:nth-child(2)') do
            expect(page).to have_css('h3', text: 'Blocked by')
            expect(page).to have_link(issue_d.title)
          end
          within('[data-testid="work-item-linked-items-list"]:nth-child(3)') do
            expect(page).to have_css('h3', text: 'Related to')
            expect(page).to have_link(issue_b.title)
          end
          expect(page).to have_css('[data-testid="linked-items-count-badge"]', text: '3')
        end
      end
    end

    context 'with EE linked items shared behaviors' do
      let(:linked_item) { issue_b }

      before do
        stub_licensed_features(blocked_work_items: true)
        visit project_issue_path(project, issue_a)
      end

      it_behaves_like 'work items linked items blocking relationships'
    end
  end
end
