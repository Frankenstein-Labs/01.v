# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_security_attribute custom role', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:role) { create(:member_role, :reporter, namespace: group, read_security_attribute: true) }
  let_it_be(:membership) do
    create(:group_member, :reporter, member_role: role, user: user, group: group)
  end

  before do
    stub_licensed_features(custom_roles: true, security_attributes: true)

    # Clear and stub GraphqlKnownOperations to avoid "undefined method `map' for String" error
    Gitlab::Webpack::GraphqlKnownOperations.clear_memoization!
    allow(Gitlab::Webpack::GraphqlKnownOperations).to receive(:load).and_return(['SubgroupsAndProjects'])
  end

  describe "GraphQL queries" do
    let_it_be(:category) { create(:security_category, namespace: group) }
    let_it_be(:attribute) { create(:security_attribute, namespace: group, security_category: category) }
    let_it_be(:project_attribute) do
      create(:project_to_security_attribute, project: project, security_attribute: attribute)
    end

    let(:query) do
      <<~GQL
        query SubgroupsAndProjects($fullPath: ID!, $projectsFirst: Int,
          $projectsAfter: String, $search: String, $hasSearch: Boolean!) {
          group(fullPath: $fullPath) {
            id
            projects(
              first: $projectsFirst
              after: $projectsAfter
              search: $search
              includeSubgroups: $hasSearch
              includeArchived: false
            ) @skip(if: $hasSearch) {
              pageInfo {
                hasNextPage
                endCursor
              }
              nodes {
                id
                name
                path
                fullPath
                securityAttributes {
                  nodes {
                    id
                    securityCategory {
                      id
                      name
                    }
                    name
                    description
                    color
                  }
                }
              }
            }
          }
        }
      GQL
    end

    let(:variables) do
      {
        fullPath: group.full_path,
        search: "",
        hasSearch: false,
        projectsFirst: 20,
        projectsAfter: nil
      }
    end

    describe 'security attributes query for projects' do
      it 'can access security attributes for projects' do
        post_graphql(query, current_user: user, variables: variables)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_blank

        projects_data = graphql_data.dig('group', 'projects', 'nodes')
        expect(projects_data).to be_present
        expect(projects_data.first.dig('securityAttributes', 'nodes')).not_to be_empty
      end
    end

    context 'when user does not have the custom role' do
      let_it_be(:user_without_permission) { create(:user) }
      let_it_be(:membership_without_role) do
        create(:group_member, :guest, user: user_without_permission, group: group)
      end

      it 'cannot access security attributes' do
        post_graphql(query, current_user: user_without_permission, variables: variables)

        expect(response).to have_gitlab_http_status(:success)

        # Authorization should prevent access - either through errors or empty results
        if graphql_errors.blank?
          projects_data = graphql_data.dig('group', 'projects', 'nodes')
          expect(projects_data.first.dig('securityAttributes', 'nodes')).to be_empty
        else
          expect(graphql_errors).to be_present
        end
      end
    end
  end
end
