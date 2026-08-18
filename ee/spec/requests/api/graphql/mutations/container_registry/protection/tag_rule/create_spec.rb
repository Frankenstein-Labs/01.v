# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating the container registry tag protection rule', :aggregate_failures, feature_category: :container_registry do
  include ContainerRegistryHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }

  let(:input) do
    {
      project_path: project.full_path,
      tag_name_pattern: 'tag-name-pattern',
      minimum_access_level_for_push: nil,
      minimum_access_level_for_delete: nil
    }
  end

  let(:mutation) do
    graphql_mutation(:create_container_protection_tag_rule, input,
      <<~QUERY
      containerProtectionTagRule {
        id
        tagNamePattern
      }
      clientMutationId
      errors
      QUERY
    )
  end

  let(:mutation_response) { graphql_mutation_response(:create_container_protection_tag_rule) }

  before do
    stub_gitlab_api_client_to_support_gitlab_api(supported: true)
    stub_licensed_features(container_registry_immutable_tag_rules: true)
  end

  subject(:post_graphql_mutation_request) do
    post_graphql_mutation(mutation, current_user: current_user)
  end

  shared_examples 'not persisting changes' do
    it { expect { post_graphql_mutation_request }.not_to change { ::ContainerRegistry::Protection::TagRule.count } }
  end

  context 'with an immutable tag rule (both access levels blank)' do
    context 'with an authorized user' do
      let_it_be(:current_user) { create(:user, owner_of: project) }

      it 'returns the created tag protection rule' do
        post_graphql_mutation_request.tap do
          expect(mutation_response).to include(
            'errors' => be_blank,
            'containerProtectionTagRule' => {
              'id' => be_present,
              'tagNamePattern' => input[:tag_name_pattern]
            }
          )
        end
      end

      it 'creates container registry protection rule in the database' do
        expect do
          post_graphql_mutation_request
        end.to change {
                 ::ContainerRegistry::Protection::TagRule.where(
                   project: project,
                   tag_name_pattern: input[:tag_name_pattern]
                 ).count
               }.by(1)
      end
    end

    context 'with an unauthorized user' do
      it_behaves_like 'returning a mutation error',
        'Unauthorized to create an immutable protection rule for container image tags'
    end

    context 'when the feature is unlicensed' do
      before do
        stub_licensed_features(container_registry_immutable_tag_rules: false)
      end

      it_behaves_like 'not persisting changes'
    end
  end
end
