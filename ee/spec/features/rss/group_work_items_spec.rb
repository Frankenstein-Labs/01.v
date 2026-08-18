# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project Work Items RSS Feed', feature_category: :planning_views do
  describe 'GET /work_items' do
    let!(:user) { create(:user, developer_of: project) }

    let_it_be(:group) { create(:group, :private) }
    let_it_be(:project) { create(:project, group: group) }

    let!(:work_item) { create(:work_item, author: user, project: project) }

    context 'with custom field filtering' do
      include_context 'with group configured with custom fields'

      let_it_be(:current_user) { create(:user, developer_of: group) }

      let_it_be(:project) { create(:project, namespace: group) }

      let!(:work_item_with_option_1) do
        create(:work_item, author: user, project: project, title: 'work item <with> option 1',
          work_item_type: issue_type)
      end

      let!(:work_item_with_option_2) do
        create(:work_item, author: user, project: project, title: 'work item <with> option 2',
          work_item_type: issue_type)
      end

      let!(:work_item_without_custom_field) do
        create(:work_item, author: user, project: project, title: 'work item <without> custom field',
          work_item_type: issue_type)
      end

      before_all do
        project.add_developer(current_user)
      end

      before do
        stub_licensed_features(custom_fields: true)

        create(:work_item_select_field_value,
          work_item: work_item_with_option_1,
          custom_field: select_field,
          custom_field_select_option: select_option_1)

        create(:work_item_select_field_value,
          work_item: work_item_with_option_2,
          custom_field: select_field,
          custom_field_select_option: select_option_2)
      end

      where(:param_name) do
        %w[
          custom-field
          custom_field
        ]
      end

      with_them do
        it 'filters work items by custom field value' do
          custom_field_params = { select_field.id.to_s => [select_option_2.id.to_s] }

          visit group_work_items_path(group, :atom, feed_token: user.feed_token, param_name => custom_field_params)

          expect(body).to have_selector('entry title', count: 1)
          expect(body).to have_selector('entry title', exact_text: 'work item <with> option 2')
        end
      end
    end
  end
end
