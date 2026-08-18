# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.workItemTypeIconDefinitions', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }

  let(:query) do
    <<~QUERY
      query {
        workItemTypeIconDefinitions {
          name
          label
        }
      }
    QUERY
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
  end

  it 'returns all available icon definitions' do
    post_graphql(query, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect_graphql_errors_to_be_empty

    icon_definitions = graphql_data['workItemTypeIconDefinitions']

    expect(icon_definitions.size).to eq(WorkItems::TypesFramework::IconDefinitions::ICON_DEFINITIONS.size)

    issue_icon = icon_definitions.find { |icon| icon['name'] == 'work-item-issue' }
    expect(issue_icon).to include(
      'name' => 'work-item-issue',
      'label' => 'Document'
    )
  end

  context 'when licensed feature is not available' do
    before do
      stub_licensed_features(configurable_work_item_types: false)
    end

    it 'returns an empty array' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_data['workItemTypeIconDefinitions']).to be_empty
    end
  end
end
