# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'container repository details', feature_category: :container_registry do
  include_context 'container registry client stubs'
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:container_repository) { create(:container_repository, project:) }

  let(:user) { project.first_owner }
  let(:container_repository_global_id) { container_repository.to_global_id.to_s }
  let(:tags) { %w[latest tag1 tag2 tag3 tag4 tag5] }
  let(:container_repository_details_response) { graphql_data['containerRepository'] }
  let(:variables) { { id: container_repository_global_id } }

  subject(:graphql_query) { post_graphql(query, current_user: user, variables: variables) }

  before do
    stub_container_registry_config(enabled: true)
    stub_container_registry_tags(repository: container_repository.path, tags: tags)
  end

  context 'for protection field' do
    let(:raw_tags_response) { [{ name: 'latest', digest: 'sha256:123' }] }
    let(:response_body) { { response_body: ::Gitlab::Json.parse(raw_tags_response.to_json) } }
    let(:tag_permissions_response) { container_repository_details_response.dig('tags', 'nodes')[0]['protection'] }

    let(:query) do
      <<~GQL
        query($id: ContainerRepositoryID!) {
          containerRepository(id: $id) {
            tags(first: 5) {
              nodes {
                protection {
                  minimumAccessLevelForPush
                  minimumAccessLevelForDelete
                }
              }
            }
          }
        }
      GQL
    end

    before_all do
      create(
        :container_registry_protection_tag_rule,
        project: project,
        tag_name_pattern: 'latest',
        minimum_access_level_for_push: Gitlab::Access::MAINTAINER,
        minimum_access_level_for_delete: Gitlab::Access::OWNER
      )

      create(
        :container_registry_protection_tag_rule,
        project: project,
        tag_name_pattern: '.*',
        minimum_access_level_for_push: Gitlab::Access::OWNER,
        minimum_access_level_for_delete: Gitlab::Access::MAINTAINER
      )

      create(
        :container_registry_protection_tag_rule,
        project: project,
        tag_name_pattern: 'non-matching-pattern',
        minimum_access_level_for_push: Gitlab::Access::ADMIN,
        minimum_access_level_for_delete: Gitlab::Access::ADMIN
      )
    end

    context 'when there is an immutable rule' do
      before_all do
        create(
          :container_registry_protection_tag_rule,
          :immutable,
          project: project,
          tag_name_pattern: 'la'
        )
      end

      before do
        stub_licensed_features(container_registry_immutable_tag_rules: true)
      end

      it 'returns the maximum access fields from the matching protection rules' do
        graphql_query

        expect(tag_permissions_response).to eq(
          {
            'minimumAccessLevelForPush' => nil,
            'minimumAccessLevelForDelete' => nil
          }
        )
      end

      context 'when the feature is unlicensed' do
        before do
          stub_licensed_features(container_registry_immutable_tag_rules: false)
        end

        it 'ignores the immutable rule' do
          graphql_query

          expect(tag_permissions_response).to eq(
            {
              'minimumAccessLevelForPush' => 'OWNER',
              'minimumAccessLevelForDelete' => 'OWNER'
            }
          )
        end
      end
    end
  end
end
