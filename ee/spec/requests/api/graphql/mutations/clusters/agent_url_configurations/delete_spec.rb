# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a cluster agent URL configuration', feature_category: :deployment_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:cluster_agent) { create(:cluster_agent, project: project) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }

  before do
    stub_licensed_features(cluster_receptive_agents: true)
    stub_application_setting(receptive_cluster_agents_enabled: true)
  end

  context 'with project permissions' do
    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_cluster_agent_url_configuration do
      let(:url_configuration) { create(:cluster_agent_url_configuration, agent: cluster_agent) }
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:mutation) do
        graphql_mutation(:cluster_agent_url_configuration_delete,
          { id: url_configuration.to_global_id.to_s }, 'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
