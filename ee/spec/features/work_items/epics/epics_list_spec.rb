# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'epics list', :js, feature_category: :planning_views do
  include FilteredSearchHelpers

  let_it_be(:group) { create(:group, :public, name: 'group') }
  let_it_be(:user) { create(:user) }
  let_it_be(:user_dev) { create(:user) }
  let_it_be(:bug_label) { create(:group_label, group: group, title: 'Bug') }
  let_it_be(:docs_label) { create(:group_label, group: group, title: 'Documentation') }
  let_it_be(:enhancement_label) { create(:group_label, group: group, title: 'Enhancement') }
  let_it_be(:critical_label) { create(:group_label, group: group, title: 'Critical') }
  let_it_be(:group_internal) { create(:group, :internal, name: 'group internal') }

  before do
    stub_licensed_features(epics: true)
    sign_in(user)
  end

  describe 'epics list' do
    available_tokens = ['Author', 'Label', 'My reaction']
    default_sort_option = 'Created date'
    available_sort_options = [default_sort_option, 'Updated date', 'Start date', 'Due date', 'Title']

    describe 'within a group' do
      let_it_be(:epic1) do
        create(:epic, group: group, start_date: '2020-12-15', end_date: '2021-1-15', labels: [docs_label])
      end

      let_it_be(:epic2, freeze: false) do
        create(:epic, group: group, start_date: '2020-12-15', labels: [docs_label, enhancement_label])
      end

      let_it_be(:epic3) { create(:epic, group: group, end_date: '2021-1-15', labels: [enhancement_label]) }
      let_it_be(:blocked_epic, freeze: false) { create(:epic, group: group, end_date: '2022-1-15') }
      let_it_be(:epic_link, freeze: false) do
        create(:related_epic_link, source: epic2, target: blocked_epic, link_type: IssuableLink::TYPE_BLOCKS)
      end

      let_it_be(:award_emoji_star) { create(:award_emoji, name: 'star', user: user, awardable: epic1) }
      let_it_be(:award_emoji_upvote) { create(:award_emoji, :upvote, user: user, awardable: epic1) }
      let_it_be(:award_emoji_downvote) { create(:award_emoji, :downvote, user: user, awardable: epic2) }

      shared_examples 'epic list' do
        it 'renders epics list', :aggregate_failures do
          expect(page).to have_selector('[data-testid="saved-views-default-view-selector"]')
          expect(page).to have_selector('[data-testid="issuable-search-container"]')
          expect(page).to have_selector('[data-testid="issuable-container"]', count: 4)
        end

        it 'renders epics item with metadata', :aggregate_failures do
          page.within(".issuable-list #issuable_#{epic2.work_item.id}.issue") do
            expect(page).to have_link(epic2.title)
            expect(page).to have_text("##{epic2.iid}")
            expect(page).to have_selector('.issuable-meta [data-testid="issuable-downvotes"]')
            expect(page.find('.issuable-meta [data-testid="relationship-blocks-icon"]')).to have_content('1')
            expect(page).to have_text(%r{created .* by #{epic2.author.name}})
          end

          page.within(".issuable-list #issuable_#{epic1.work_item.id}.issue") do
            expect(page).to have_selector('.issuable-meta [data-testid="issuable-upvotes"]')
          end
        end

        it 'renders epic item timeframe', :aggregate_failures do
          expect(page.find('.issue:nth-of-type(3)')).to have_text('Dec 15, 2020 – No due date')
          expect(page.find('.issue:nth-of-type(4)')).to have_text('Dec 15, 2020 – Jan 15, 2021')
          expect(page.find('.issue:nth-of-type(2)')).to have_text('Jan 15, 2021')
        end
      end

      context 'when signed in' do
        before_all do
          group.add_developer(user)
          group.add_developer(user_dev)
        end

        before do
          visit group_epics_path(group)
        end

        it 'renders epics list header actions', :aggregate_failures do
          expect(page).to have_button('Bulk edit')
        end

        it_behaves_like 'epic list'

        it_behaves_like 'filtered search bar', available_tokens, available_sort_options, default_sort_option,
          has_display_drawer: true

        it 'filters epics list based on labels with "=" operator' do
          select_tokens 'Label', '=', docs_label.title, submit: true

          page.within('.issuable-list-container') do
            expect(page.find('.issuable-list')).to have_selector('li.issue', count: 2)
          end
        end

        it 'filters epics list based on labels with "!=" operator', :aggregate_failures do
          select_tokens 'Label', '=', docs_label.title
          select_tokens 'Label', '!=', enhancement_label.title, submit: true

          page.within('.issuable-list-container .issuable-list') do
            expect(page).to have_selector('li.issue', count: 1)
            expect(page.find('li.issue .issuable-info')).not_to have_selector('.gl-label',
              text: enhancement_label.title)
          end
        end

        it 'filters epics list based on labels with "||" operator', :aggregate_failures do
          select_tokens 'Label', '||', docs_label.title, enhancement_label.title, submit: true

          page.within('.issuable-list-container .issuable-list') do
            expect(page).to have_selector('li.issue', count: 3)
          end
        end

        context 'with subgroup epics' do
          let_it_be(:subgroup) { create(:group, :public, parent: group, name: 'subgroup') }
          let_it_be(:subgroup_epic) { create(:epic, group: subgroup) }
          let_it_be(:subgroup_epic2) { create(:epic, group: subgroup) }

          it 'filters by group', :aggregate_failures do
            expect(page).to have_selector('li.issue', count: 6)

            select_tokens 'Group', group.name, submit: true

            expect(page).to have_selector('li.issue', count: 4)

            click_button 'Clear'

            select_tokens 'Group', subgroup.name, submit: true

            expect(page).to have_selector('li.issue', count: 2)
          end
        end

        it 'shows bulk editing sidebar with actions and labels select dropdown', :aggregate_failures do
          click_button 'Bulk edit'

          page.within('.issuable-list-container aside.right-sidebar') do
            expect(page).to have_button('Update selected', disabled: true)
            expect(page).to have_button('Cancel')

            expect(page).to have_selector('form#work-item-list-bulk-edit')
            expect(page).to have_button('Select labels', disabled: true)
          end
        end

        it 'shows checkboxes for selecting epics while bulk editing sidebar is visible', :aggregate_failures do
          click_button 'Bulk edit'

          expect(page).to have_selector('.vue-filtered-search-bar-container input[type="checkbox"]')

          page.within('.issuable-list-container') do
            expect(page.first('.issuable-list li.issue')).to have_selector('.gl-form-checkbox input[type="checkbox"]')
          end
        end

        it 'applies label to multiple epics from bulk editing sidebar', :aggregate_failures,
          quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/3125' do
          # TODO: remove threshold after epic-work item sync
          # issue: https://gitlab.com/gitlab-org/gitlab/-/issues/438295
          allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(175)

          # Verify that label `Bug` is not applied already
          expect(find('.issuable-list li.issue .issuable-info',
            match: :first)).not_to have_selector('.gl-label', text: bug_label.title)

          click_button 'Bulk edit'
          page.within('.vue-filtered-search-bar-container') do
            page.find('input[type="checkbox"]').click
          end

          # Bulk edit all epics to apply label
          page.within('.issuable-list-container') do
            page.within('aside.right-sidebar') do
              within_testid('bulk-edit-add-labels') do
                click_button('Select labels')

                list_item = find('.gl-new-dropdown-item', match: :first)
                expect(list_item).to have_text(bug_label.title)
                list_item.click
              end
              click_button 'Update selected'
            end
          end

          # Verify that label is applied
          expect(find('.issuable-list li.issue .issuable-info',
            match: :first)).to have_selector('.gl-label', text: bug_label.title)
        end
      end

      context 'when signed out' do
        before do
          sign_out user
          visit group_epics_path(group)
        end

        it_behaves_like 'epic list'
      end
    end

    describe 'within a sub-group group' do
      let_it_be(:subgroup) { create(:group, parent: group, name: 'subgroup') }
      let_it_be(:sub_epic1) { create(:epic, group: subgroup, start_date: '2020-12-15', end_date: '2021-1-15') }
      let_it_be(:sub_epic2) { create(:epic, group: subgroup, start_date: '2020-12-15') }
      let_it_be(:award_emoji_star) { create(:award_emoji, name: 'star', user: user, awardable: sub_epic1) }

      before_all do
        subgroup.add_developer(user)
        subgroup.add_developer(user_dev)
      end

      before do
        visit group_epics_path(subgroup)
      end

      it_behaves_like 'filtered search bar', available_tokens, available_sort_options, default_sort_option,
        has_display_drawer: true
    end

    context 'with pagination' do
      let(:issuable_container) { '[data-testid="issuable-container"]' }
      let_it_be(:work_items) do
        create_list(:work_item, 10, :epic, namespace: group)
        create_list(:work_item, 10, :epic, namespace: group)
        create_list(:work_item, 5, :epic, namespace: group)
      end

      before do
        visit group_epics_path(group)
      end

      it_behaves_like 'pagination on the work items list page'

      it 'respects per_page parameter in URL' do
        visit group_epics_path(group, first_page_size: 50)

        expect(page).to have_selector(issuable_container, count: 25)
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
          sign_in(user)
          visit group_epics_path(group_internal, state: :all)
          wait_for_all_requests
        end

        it_behaves_like 'shows all items in the list' do
          let(:open_item) { open_work_item }
          let(:closed_item) { closed_work_item }
        end
      end
    end
  end
end
