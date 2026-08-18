# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Epic work item detail', :js, feature_category: :team_planning do
  include DragTo
  include ListboxHelpers

  let_it_be_with_refind(:user) { create(:user) }
  let_it_be_with_refind(:user2) { create(:user, name: 'John') }

  let_it_be(:group) { create(:group, :nested, developers: user) }
  let_it_be(:label) { create(:group_label, group: group) }
  let_it_be(:label2) { create(:group_label, group: group) }
  let_it_be_with_reload(:work_item) do
    create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group, labels: [label])
  end

  let_it_be(:emoji_upvote) { create(:award_emoji, :upvote, awardable: work_item, user: user2) }
  let(:work_items_path) { group_epic_path(group, work_item.iid) }
  let(:work_items_index_path) { group_work_items_path(group) }
  let(:epics_index_path) { group_epics_path(group) }

  context 'for signed in user' do
    let(:child_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let(:linked_item) { child_item }

    before do
      stub_licensed_features(epic_colors: true, epics: true, issuable_health_status: true, linked_items_epics: true,
        related_epics: true, subepics: true)
      page.current_window.resize_to(1200, 2400)
      sign_in(user)
      visit work_items_path
    end

    it 'shows work item breadcrumb links', :aggregate_failures do
      within_testid('breadcrumb-links') do
        expect(page).to have_link(group.name, href: group_path(group))

        expect(page).to have_link('Work items', href: work_items_index_path)
        expect(find('nav:last-of-type li:last-of-type')).to have_link(work_item.to_reference,
          href: group_work_item_path(group, work_item.iid))
      end
    end

    it_behaves_like 'work items title'
    it_behaves_like 'work items award emoji'
    it_behaves_like 'work items hierarchy', 'work-item-tree', :epic
    it_behaves_like 'work items linked items', true

    context 'when there is a pre-existing closed linked item' do
      let(:closed_linked_item) { create(:work_item, :closed, project: nil, namespace: group, author: user) }

      before do
        create(:work_item_link, source: work_item, target: closed_linked_item)
        visit work_items_path
      end

      it 'toggles display of closed linked items', :aggregate_failures do
        within_testid('work-item-relationships') do
          expect(page).to have_link(closed_linked_item.title)

          click_button 'Display options'
          click_button 'Show closed items'
          send_keys :escape

          expect(page).not_to have_link(closed_linked_item.title)
          expect(page).to have_selector('[data-testid="work-item-show-closed"]')

          find_by_testid('work-item-show-closed').find('button').click

          expect(page).to have_link(closed_linked_item.title)
        end
      end
    end

    it_behaves_like 'work items linked items blocking relationships'
    it_behaves_like 'work items toggle status button'

    it_behaves_like 'work items todos'
    it_behaves_like 'work items lock discussion', 'epic'
    it_behaves_like 'work items confidentiality'
    it_behaves_like 'work items notifications'

    it_behaves_like 'work items assignees'
    it_behaves_like 'work items labels', 'group'
    it_behaves_like 'work items rolled up dates'

    context 'with quarantine', quarantine: {
      issue: [
        'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/2929',
        'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/2924'
      ]
    } do
      it_behaves_like 'work items health status'
    end

    it_behaves_like 'work items color'

    context 'with quarantine',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/5429' do
      it_behaves_like 'work items time tracking'
    end

    describe 'work item hierarchy',
      quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/4998' do
      let(:child1) { create(:work_item, :epic_with_legacy_epic, namespace: group, title: 'Child 1') }
      let(:child2) { create(:work_item, :epic_with_legacy_epic, namespace: group, title: 'Child 2') }
      let(:child1a) { create(:work_item, :epic_with_legacy_epic, namespace: group, title: 'Child 1a') }

      describe 'nested children' do
        before do
          create(:parent_link, work_item_parent: work_item, work_item: child1)
          create(:parent_link, work_item_parent: work_item, work_item: child2)
          create(:parent_link, work_item_parent: child1, work_item: child1a)
          page.refresh
        end

        it 'can be expanded, removed, and re-added', :aggregate_failures do
          within_testid 'work-item-tree' do
            expect(page).to have_link 'Child 1'
            expect(page).to have_link 'Child 2'
            expect(page).not_to have_link 'Child 1a'

            click_button('Expand', match: :first)

            expect(page).to have_link 'Child 1'
            expect(page).to have_link 'Child 2'
            expect(page).to have_link 'Child 1a'

            # hover over the "Child 1a" link so the first "Remove" button is the one to remove "Child 1a"
            find_link('Child 1a').hover
            click_button 'Remove', match: :first

            expect(page).not_to have_link 'Child 1a'
          end

          within '.gl-toast' do
            expect(page).to have_content(_('Child removed'))

            find('a', text: 'Undo').click # click_link doesn't work here for some reason
          end

          within_testid 'work-item-tree' do
            expect(page).to have_link 'Child 1a'
          end
        end
      end
    end
  end

  context 'without epics license',
    quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/6964' do
    before do
      stub_licensed_features(epics: false)
      sign_in(user)
      visit work_items_path
    end

    it 'shows 404' do
      expect(page).to have_content 'Page not found'
    end
  end
end
