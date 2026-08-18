# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a list of work item types for a group EE', feature_category: :team_planning do
  let_it_be(:namespace) { create(:group, :private) }
  let_it_be(:developer) { create(:user, developer_of: namespace) }
  let(:parent) { namespace }
  let(:current_user) { developer }

  it_behaves_like 'graphql work item type list request spec', 'with work item types request context EE'

  it_behaves_like 'graphql work item type list request spec EE'

  context 'with custom fields widget' do
    include GraphqlHelpers

    include_context 'with group configured with custom fields'

    let(:query) do
      graphql_query_for('namespace', { 'fullPath' => group.full_path },
        query_nodes('WorkItemTypes', work_item_type_fields)
      )
    end

    let(:work_item_type_fields) do
      <<~GRAPHQL
        id
        name
        widgetDefinitions {
          type
          ... on WorkItemWidgetDefinitionCustomFields {
            customFieldValues {
              customField {
                id
              }
            }
          }
        }
      GRAPHQL
    end

    before do
      stub_licensed_features(custom_fields: true)
    end

    it 'returns custom fields available for each work item type' do
      post_graphql(query, current_user: current_user)

      custom_field_widgets_per_type = graphql_data_at('namespace', 'workItemTypes', 'nodes').map do |type|
        {
          work_item_type_id: type['id'],
          custom_fields_widget: type['widgetDefinitions'].find { |widget| widget['type'] == 'CUSTOM_FIELDS' }
        }
      end

      expect(custom_field_widgets_per_type).to include(
        {
          work_item_type_id: issue_type.to_gid.to_s,
          custom_fields_widget: {
            'type' => 'CUSTOM_FIELDS',
            'customFieldValues' => [
              { 'customField' => { 'id' => select_field.to_gid.to_s } },
              { 'customField' => { 'id' => number_field.to_gid.to_s } },
              { 'customField' => { 'id' => date_field.to_gid.to_s } },
              { 'customField' => { 'id' => text_field.to_gid.to_s } },
              { 'customField' => { 'id' => multi_select_field.to_gid.to_s } }
            ]
          }
        }
      )

      expect(custom_field_widgets_per_type).to include(
        {
          work_item_type_id: task_type.to_gid.to_s,
          custom_fields_widget: {
            'type' => 'CUSTOM_FIELDS',
            'customFieldValues' => [
              { 'customField' => { 'id' => select_field.to_gid.to_s } },
              { 'customField' => { 'id' => multi_select_field.to_gid.to_s } },
              { 'customField' => { 'id' => field_on_other_type.to_gid.to_s } }
            ]
          }
        }
      )
    end

    it 'does not include CUSTOM_FIELDS widget for ineligible work item types' do
      post_graphql(query, current_user: current_user)
      expect_graphql_errors_to_be_empty

      work_item_types = graphql_data_at('namespace', 'workItemTypes', 'nodes')
      types_with_custom_fields = work_item_types.select do |type|
        type['widgetDefinitions'].any? { |widget| widget['type'] == 'CUSTOM_FIELDS' }
      end

      type_names_with_custom_fields = types_with_custom_fields.pluck('name')

      expect(type_names_with_custom_fields).not_to be_empty
      expect(type_names_with_custom_fields).not_to include('Incident', 'Ticket', 'Test Case', 'Requirement')
    end

    context 'when loading associated fields' do
      let(:work_item_type_fields) do
        <<~GRAPHQL
          id
          widgetDefinitions {
            type
            ... on WorkItemWidgetDefinitionCustomFields {
              customFieldValues {
                customField {
                  id
                  selectOptions { id }
                }
              }
            }
          }
        GRAPHQL
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        post_graphql(query, current_user: current_user)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          post_graphql(query, current_user: current_user)
        end
        expect_graphql_errors_to_be_empty

        other_type = build(:work_item_system_defined_type, :issue)
        create(:custom_field, namespace: group, work_item_types: [other_type])

        expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
        expect_graphql_errors_to_be_empty

        issue_type_data = graphql_data_at(:namespace, :workItemTypes, :nodes).find do |t|
          t['id'] == issue_type.to_gid.to_s
        end
        custom_fields_widget = issue_type_data['widgetDefinitions'].find { |d| d['type'] == 'CUSTOM_FIELDS' }
        select_option_ids = custom_fields_widget['customFieldValues'].flat_map do |v|
          v.dig('customField', 'selectOptions').pluck('id')
        end

        expect(select_option_ids).to match_array([
          select_option_1,
          select_option_2,
          multi_select_option_1,
          multi_select_option_2,
          multi_select_option_3
        ].map { |o| o.to_global_id.to_s })
      end
    end

    context 'with custom work item types' do
      let_it_be(:custom_type) { create(:work_item_custom_type, namespace: group, name: 'Feature') }

      before do
        stub_saas_features(namespace_scoped_work_item_types: true)
      end

      it 'returns only custom fields associated with the custom type, not fields from other types' do
        custom_type_field = create(:custom_field, namespace: group, field_type: 'text',
          name: 'Custom type field', work_item_types: [custom_type])

        post_graphql(query, current_user: current_user)
        expect_graphql_errors_to_be_empty

        work_item_types = graphql_data_at('namespace', 'workItemTypes', 'nodes')

        custom_type_data = work_item_types.find { |t| t['name'] == 'Feature' }
        expect(custom_type_data).to be_present

        custom_fields_widget = custom_type_data['widgetDefinitions'].find { |w| w['type'] == 'CUSTOM_FIELDS' }
        custom_field_ids = custom_fields_widget['customFieldValues'].map { |v| v.dig('customField', 'id') }

        expect(custom_field_ids).to contain_exactly(custom_type_field.to_gid.to_s)
        expect(custom_field_ids).not_to include(text_field.to_gid.to_s)
        expect(custom_field_ids).not_to include(number_field.to_gid.to_s)
      end

      it 'returns empty custom fields for custom types with no associated fields' do
        post_graphql(query, current_user: current_user)
        expect_graphql_errors_to_be_empty

        work_item_types = graphql_data_at('namespace', 'workItemTypes', 'nodes')

        custom_type_data = work_item_types.find { |t| t['name'] == 'Feature' }
        custom_fields_widget = custom_type_data['widgetDefinitions'].find { |w| w['type'] == 'CUSTOM_FIELDS' }

        expect(custom_fields_widget['customFieldValues']).to be_blank
      end

      context 'when a custom field is assigned to a converted custom work item type' do
        let_it_be(:converted_type) do
          create(:work_item_custom_type, :converted_from_issue, namespace: group, name: 'Renamed Issue')
        end

        let_it_be(:field_for_converted_type) do
          create(:custom_field, namespace: group, field_type: 'text',
            name: 'Field for converted type', work_item_types: [converted_type])
        end

        it 'stores the association using the persistable (system-defined) id' do
          # Without the persistable_id fix, the association would be stored against
          # the custom type's AR primary key rather than the system-defined id that
          # work items actually reference.
          stored_type_ids = field_for_converted_type.work_item_type_custom_fields.map(&:work_item_type_id)

          expect(stored_type_ids).to contain_exactly(
            converted_type.converted_from_system_defined_type_identifier
          )
        end
      end
    end

    context 'with the agent_plan widget on a custom work item type' do
      let_it_be(:agent_plan_custom_type) do
        create(:work_item_custom_type, namespace: group, name: 'Feature')
      end

      before do
        stub_saas_features(namespace_scoped_work_item_types: true)
        stub_licensed_features(ai_workflows: true)
      end

      subject(:custom_type_widget_types) do
        post_graphql(query, current_user: current_user)

        custom_type_data = graphql_data_at('namespace', 'workItemTypes', 'nodes').find { |t| t['name'] == 'Feature' }
        custom_type_data['widgetDefinitions'].pluck('type')
      end

      it 'includes the AGENT_PLAN widget' do
        expect(custom_type_widget_types).to include('AGENT_PLAN')
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(workplan: false)
        end

        it 'excludes the AGENT_PLAN widget' do
          expect(custom_type_widget_types).not_to include('AGENT_PLAN')
        end
      end
    end
  end
end
