# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Getting starredProjects of the user', feature_category: :groups_and_projects do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:user_params) { { username: current_user.username } }

  let(:user_fields) { 'starredProjects { nodes { id } }' }
  let(:query) { graphql_query_for(:user, user_params, user_fields) }
  let(:path) { %i[user starred_projects nodes] }

  it_behaves_like 'projects graphql query with SAML session filtering' do
    before do
      current_user.toggle_star(saml_project)
    end
  end

  context 'when requesting user permissions' do
    let_it_be(:group) { create(:group) }
    let_it_be(:projects) { create_list(:project, 3, :private, group: group) }
    let_it_be(:member_role) { create(:member_role, :guest, :read_code, namespace: group) }

    let(:user_fields) do
      <<~QUERY
        starredProjects {
          nodes {
            id
            userPermissions {
              readProject
              removeProject
            }
          }
        }
      QUERY
    end

    before do
      stub_licensed_features(custom_roles: true)

      projects.each do |project|
        create(:project_member, :guest, project: project, user: current_user, member_role: member_role)
        current_user.toggle_star(project)
      end
    end

    it_behaves_like 'a working graphql query that returns data' do
      before do
        post_graphql(query, current_user: current_user)
      end

      it 'returns data', :aggregate_failures do
        expect(graphql_errors).to be_nil

        expect(graphql_data_at(:user, :starred_projects, :nodes, 0, :user_permissions)).to eq({
          'readProject' => true,
          'removeProject' => false
        })
      end
    end

    it 'batches data', :use_sql_query_cache do
      recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(query, current_user: current_user)
      end

      custom_ability_queries = recorder.occurrences_starting_with(/.*custom_permissions.*/)

      expect(custom_ability_queries.values.sum).to eq(1)
    end
  end
end
