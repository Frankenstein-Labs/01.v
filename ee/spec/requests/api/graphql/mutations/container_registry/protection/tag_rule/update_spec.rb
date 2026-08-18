# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating the container registry tag protection rule', :aggregate_failures, feature_category: :container_registry do
  include ContainerRegistryHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:container_protection_tag_rule) { create(:container_registry_protection_tag_rule, project:) }

  let(:current_user) { project.first_owner }
  let(:input) do
    {
      id: container_protection_tag_rule.to_global_id,
      tag_name_pattern: 'v2*',
      minimum_access_level_for_delete: 'ADMIN',
      minimum_access_level_for_push: 'OWNER'
    }
  end

  let(:mutation) do
    graphql_mutation(:update_container_protection_tag_rule, input,
      <<~QUERY
      containerProtectionTagRule {
        tagNamePattern
        minimumAccessLevelForDelete
        minimumAccessLevelForPush
      }
      clientMutationId
      errors
      QUERY
    )
  end

  let(:mutation_response) { graphql_mutation_response(:update_container_protection_tag_rule) }

  before do
    stub_gitlab_api_client_to_support_gitlab_api(supported: true)
  end

  subject(:post_graphql_mutation_request) { post_graphql_mutation(mutation, current_user:) }

  it 'returns the updated container registry tag protection rule', :aggregate_failures do
    post_graphql_mutation_request.tap do
      expect(mutation_response).to include(
        'errors' => be_blank,
        'containerProtectionTagRule' => {
          'tagNamePattern' => input[:tag_name_pattern],
          'minimumAccessLevelForDelete' => input[:minimum_access_level_for_delete],
          'minimumAccessLevelForPush' => input[:minimum_access_level_for_push]
        }
      )

      expect(container_protection_tag_rule.reset).to have_attributes(
        tag_name_pattern: input[:tag_name_pattern],
        minimum_access_level_for_push: input[:minimum_access_level_for_push].downcase,
        minimum_access_level_for_delete: input[:minimum_access_level_for_delete].downcase
      )
    end
  end
end
