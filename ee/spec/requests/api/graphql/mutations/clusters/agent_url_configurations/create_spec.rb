# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a new cluster agent URL configuration', feature_category: :deployment_management do
  include GraphqlHelpers

  let_it_be(:cluster_agent) { create(:cluster_agent) }
  let_it_be(:current_user) { create(:user, maintainer_of: cluster_agent.project) }

  before do
    stub_licensed_features(cluster_receptive_agents: true)
    stub_application_setting(receptive_cluster_agents_enabled: true)
  end

  context 'with project permissions' do
    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_cluster_agent_url_configuration do
      let(:user) { current_user }
      let(:boundary_object) { cluster_agent.project }
      let(:mutation) do
        graphql_mutation(:cluster_agent_url_configuration_create,
          { cluster_agent_id: cluster_agent.to_global_id.to_s, url: 'grpcs://localhost:1111' },
          'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
