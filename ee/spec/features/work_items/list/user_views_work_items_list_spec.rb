# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work Items List', :js, feature_category: :planning_views do
  include Features::IterationHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group, :public) }
  let_it_be(:group_internal) { create(:group, :internal) }

  context 'when user is signed in as owner' do
    before_all do
      group.add_owner(user)
    end

    before do
      stub_licensed_features(epics: true, issuable_health_status: true, iterations: true)
      sign_in(user)
      visit group_work_items_path(group)

      wait_for_all_requests
    end

    it_behaves_like 'no work items in the list'

    context 'when the group work items list page renders' do
      let_it_be(:epic) { create(:work_item, :epic, namespace: group, title: 'Epic 1') }

      it 'shows actions based on user permissions' do
        expect(page).to have_link('New item')
        expect(page).to have_button('Bulk edit')
      end

      context 'when work item is an issue' do
        let_it_be(:project) { create(:project, :public, group: group) }
        let_it_be(:cadence) { create(:iterations_cadence, group: project.group) }
        let_it_be(:iteration) do
          create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 2.days.ago)
        end

        let_it_be(:issue) do
          create(
            :work_item,
            :issue,
            project: project,
            weight: 5,
            health_status: :on_track,
            iteration: iteration
          )
        end

        it 'display issue related metadata' do
          within(all('[data-testid="issuable-container"]')[0]) do
            expect(find_by_testid('issuable-weight-content-title').text).to have_text(5)
            expect(find_by_testid('status-text').text).to have_text('On track')
            expect(find_by_testid('iteration-attribute')).to have_content(iteration_period(iteration,
              use_thin_space: false))
          end
        end
      end

      context 'when work item is an epic' do
        let_it_be_with_reload(:label) { create(:group_label, title: 'Label 1', group: group) }
        let_it_be_with_reload(:epic_with_metadata) do
          create(
            :work_item,
            :epic,
            namespace: group,
            title: 'Epic with metadata',
            labels: [label],
            assignees: [user],
            start_date: '2025-05-01', due_date: '2025-12-31'
          )
        end

        let_it_be(:award_emoji_upvote) { create(:award_emoji, :upvote, user: user, awardable: epic_with_metadata) }
        let_it_be(:award_emoji_downvote) { create(:award_emoji, :downvote, user: user, awardable: epic_with_metadata) }

        it_behaves_like 'dates on the work items list' do
          let(:date) { 'May 1 – Dec 31, 2025' }
        end

        it 'display epic related metadata' do
          within(all('[data-testid="issuable-container"]')[0]) do
            expect(page).to have_link(label.name)
            expect(page).to have_text(%r{created .* by #{epic_with_metadata.author.name}})
            expect(page).to have_link(user.name, href: user_path(user))
          end
        end
      end
    end
  end

  context 'with internal group visibility level' do
    let_it_be(:open_work_item) { create(:work_item, :epic, namespace: group_internal, title: 'Open epic') }

    let_it_be(:closed_work_item) do
      create(:work_item, :epic, :closed, namespace: group_internal, title: 'Closed epic')
    end

    context 'when a member views all work items' do
      before_all do
        group_internal.add_developer(user)
      end

      before do
        stub_licensed_features(epics: true)
        sign_in(user)
        visit group_work_items_path(group_internal, state: :all)
        wait_for_all_requests
      end

      it_behaves_like 'shows all items in the list' do
        let(:open_item) { open_work_item }
        let(:closed_item) { closed_work_item }
      end
    end
  end
end
