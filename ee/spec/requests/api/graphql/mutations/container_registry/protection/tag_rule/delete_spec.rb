# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ContainerRegistry::Protection::TagRule::Delete, :aggregate_failures, feature_category: :container_registry do
  include ContainerRegistryHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:container_protection_rule) { create(:container_registry_protection_tag_rule, project:) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }

  let(:mutation) { graphql_mutation(:delete_container_protection_tag_rule, input) }
  let(:mutation_response) { graphql_mutation_response(:delete_container_protection_tag_rule) }
  let(:input) { { id: container_protection_rule.to_global_id } }

  before do
    stub_gitlab_api_client_to_support_gitlab_api(supported: true)
  end

  subject(:post_graphql_mutation_request) { post_graphql_mutation(mutation, current_user:) }

  it 'includes immutable field in the response' do
    expect { post_graphql_mutation_request }
      .to change { ::ContainerRegistry::Protection::TagRule.count }.by(-1)

    expect(mutation_response).to include(
      'errors' => be_blank,
      'containerProtectionTagRule' => hash_including(
        'immutable' => container_protection_rule.immutable?
      )
    )
  end
end
