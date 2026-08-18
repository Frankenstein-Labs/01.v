# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Filter issues by custom fields', :js, feature_category: :planning_views do
  include FilteredSearchHelpers
  include_context 'with group configured with custom fields'

  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:user) { create(:user) }

  let_it_be(:issues) { create_list(:issue, 3, project: project) }

  before_all do
    project.add_maintainer(user)

    create(:work_item_select_field_value, work_item_id: issues[1].id, custom_field: select_field,
      custom_field_select_option: select_option_1)
  end

  before do
    sign_in(user)
  end

  shared_examples 'filtering by custom fields' do
    let(:query) { nil }

    context 'when custom fields feature is enabled' do
      before do
        stub_licensed_features(custom_fields: true)
      end

      it 'allows filtering by select field', :aggregate_failures do
        visit work_items_page_path

        click_filtered_search_bar

        within_testid('filtered-search-input') do
          expect(page).to have_content(select_field.name)
          expect(page).to have_content(multi_select_field.name)
          expect(page).not_to have_content(text_field.name)
          expect(page).not_to have_content(number_field.name)

          click_on select_field.name
          click_on select_option_1.value
          send_keys :enter
        end

        expect(page).to have_selector('.issue', count: 1)
        expect(page).to have_selector('.issue-title', text: issues[1].title)
      end
    end

    context 'when custom fields feature is disabled by license' do
      let(:query) { { "custom-field[#{select_field.id}]": select_option_2.id } }

      before do
        stub_licensed_features(custom_fields: false)
      end

      it 'does not show custom field tokens in filtered search or suggestions' do
        visit work_items_page_path

        click_filtered_search_bar

        aggregate_failures do
          within_testid('filtered-search-input') do
            expect(page).not_to have_content(select_field.name)
            # even if there is no name the search field might try to tokenize the id
            expect(page).not_to have_content(select_option_2.id)
            expect(page).not_to have_content(multi_select_field.name)
            expect(page).not_to have_content(text_field.name)
            expect(page).not_to have_content(number_field.name)
          end
        end
      end
    end
  end

  context 'on project work items page' do
    let(:work_items_page_path) { project_work_items_path(project, query) }

    it_behaves_like 'filtering by custom fields'
  end

  context 'on group work items page' do
    let(:work_items_page_path) { group_work_items_path(group, query) }

    it_behaves_like 'filtering by custom fields'
  end

  context 'on subgroup work items page' do
    let(:work_items_page_path) { group_work_items_path(subgroup, query) }

    it_behaves_like 'filtering by custom fields'
  end
end
