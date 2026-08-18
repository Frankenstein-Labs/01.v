# frozen_string_literal: true

RSpec.shared_examples 'getting a collection of projects EE' do
  include GraphqlHelpers

  let_it_be(:current_user, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group, developers: current_user) }
  let_it_be(:projects, freeze: false) { create_list(:project, 5, :public, group: group) }

  let(:filters) { {} }

  let(:field) { :projects }
  let(:field_graphql_name) { field.to_s.camelize(:lower) }
  let(:project_fields) { all_graphql_fields_for('Project', max_depth: 1, excluded: ['productAnalyticsState']) }
  let(:query) do
    graphql_query_for(
      field,
      filters,
      "nodes { #{project_fields} }"
    )
  end

  let(:path) { [field_graphql_name.to_sym, :nodes] }

  it 'returns data without errors' do
    post_graphql(query, current_user: current_user)

    expect(graphql_errors).to be_nil
    expect(graphql_data_at(*path)).to be_present
  end

  context 'when requesting user permissions' do
    let(:path) { [field, :nodes, 0, :user_permissions] }

    let(:query) do
      <<~QUERY
        query($first: Int!) {
          #{field_graphql_name}(membership: true, first: $first) {
            nodes {
              id
              userPermissions {
                readProject
                removeProject
              }
            }
          }
        }
      QUERY
    end

    before do
      stub_licensed_features(custom_roles: true)

      post_graphql(query, current_user: current_user, variables: { first: 1 })
    end

    it 'returns data without errors' do
      expect(graphql_errors).to be_nil
      expect(graphql_data_at(*path)).to be_present
    end

    it 'returns correct permissions data', :aggregate_failures do
      expect(graphql_errors).to be_nil

      expect(graphql_data_at(*path)).to eq({
        'readProject' => true,
        'removeProject' => false
      })
    end

    it 'avoids N+1 queries', :request_store do
      control = ActiveRecord::QueryRecorder.new do
        post_graphql(query, current_user: current_user, variables: { first: 1 })
      end

      expect do
        post_graphql(query, current_user: current_user, variables: { first: 5 })
      end.not_to exceed_query_limit(control)
    end
  end
end
