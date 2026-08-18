# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization.workItemTypes', :with_current_organization, feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user, organizations: [current_organization]) }
  let(:available_types) { ::WorkItems::TypesFramework::Provider.new(current_organization).available_types }
  let(:available_types_names) { available_types.map(&:name) }

  let(:query_param) { { 'id' => current_organization.to_gid } }
  let(:query) do
    graphql_query_for('organization', query_param,
      'workItemTypes { nodes { id name widgetDefinitions { type } } }')
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
  end

  context 'with custom work item types' do
    let!(:custom_work_item_type) do
      create(:work_item_custom_type, :with_organization, organization: current_organization)
    end

    it 'returns system-defined and custom work item types' do
      post_graphql(query, current_user: current_user)

      returned_types = graphql_data_at('organization', 'workItemTypes', 'nodes')
      type_names = returned_types.pluck('name')

      expect(type_names).to include(*available_types_names)
      expect(type_names).to include(custom_work_item_type.name)

      expected_count = available_types.count
      expect(returned_types.size).to eq(expected_count)
    end

    context 'with converted work item types' do
      let!(:converted_custom_work_item_type) do
        create(:work_item_custom_type, :with_organization, :converted_from_issue,
          organization: current_organization, name: 'Issue V2')
      end

      it 'returns system-defined, custom and converted work item types' do
        post_graphql(query, current_user: current_user)

        returned_types = graphql_data_at('organization', 'workItemTypes', 'nodes')
        type_names = returned_types.pluck('name')

        converted_type_name = converted_custom_work_item_type.converted_from_system_defined_type.name
        system_defined_type_names = available_types_names - [converted_type_name]

        expect(type_names).to include(*system_defined_type_names)
        expect(type_names).to include(custom_work_item_type.name, converted_custom_work_item_type.name)

        expected_count = available_types.count
        expect(returned_types.size).to eq(expected_count)
      end
    end
  end
end
