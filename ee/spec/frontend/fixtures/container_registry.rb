# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Container registry (JavaScript fixtures)', feature_category: :container_registry do
  include ContainerRegistryHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  describe GraphQL::Query, type: :request do
    let_it_be(:group, freeze: false) { create(:group, path: 'container-registry-group') }
    let_it_be(:project, freeze: false) { create(:project, group: group, path: 'container-registry-project') }
    let_it_be(:user, freeze: false) { create(:user) }

    describe 'Protected container image tags' do
      base_path = 'packages_and_registries/settings/project/graphql'
      project_container_protection_tag_rules_query_path =
        "#{base_path}/queries/get_container_protection_tag_rules.query.graphql"

      let(:query) { get_graphql_query_as_string(project_container_protection_tag_rules_query_path) }

      let(:variables) do
        {
          projectPath: project.full_path,
          first: 5
        }
      end

      shared_examples 'container registry protection tag rules' do |fixture_suffix|
        before do
          stub_licensed_features(container_registry_immutable_tag_rules: true)
          stub_gitlab_api_client_to_support_gitlab_api(supported: true)

          create(:container_registry_protection_tag_rule, :immutable, project:)
        end

        it "graphql/#{project_container_protection_tag_rules_query_path}.#{fixture_suffix}.json" do
          post_graphql(query, current_user: user, variables: variables)

          expect_graphql_errors_to_be_empty
        end
      end

      context 'when user has access to the project &' do
        before_all do
          project.add_owner(user)
        end

        context 'with immutable tag protection rules' do
          it_behaves_like 'container registry protection tag rules', 'immutable_rules'
        end

        context 'with immutable tag protection rules as maintainer' do
          before_all do
            project.add_maintainer(user)
          end

          it_behaves_like 'container registry protection tag rules', 'immutable_rules_maintainer'
        end
      end
    end
  end
end
