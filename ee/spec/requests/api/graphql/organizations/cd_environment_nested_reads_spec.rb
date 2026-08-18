# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cdEnvironments nested reads', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let_it_be(:environment) { create(:cd_environment, organization: organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:driver_binding) { create(:cd_environment_driver_binding, environment: environment) }
  let_it_be(:service_environment_health) do
    create(:cd_service_environment_health, environment: environment, service: service)
  end

  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:rollout) { create(:cd_rollout, version_set: version_set, application: application) }
  let_it_be(:rollout_environment) do
    create(:cd_rollout_environment, rollout: rollout, environment: environment, driver_binding: driver_binding)
  end

  let(:current_user) { organization_owner }

  let(:query) do
    <<~QUERY
      query organizationCdEnvironments($id: OrganizationsOrganizationID!) {
        organization(id: $id) {
          cdEnvironments {
            nodes {
              id
              name
              environmentDriverBindings { nodes { id version driverRef environment { id } } }
              serviceEnvironmentHealths { nodes { id health service { id } environment { id } } }
              rolloutEnvironments { nodes { id position state rollout { id } } }
            }
          }
        }
      }
    QUERY
  end

  subject(:post_query) do
    post_graphql(query, current_user: current_user, variables: { id: organization.to_global_id.to_s })
  end

  def environment_response
    graphql_dig_at(graphql_data, :organization, :cd_environments, :nodes).first
  end

  context 'when the user is an organization owner' do
    it 'resolves driver bindings and their environment' do
      post_query

      driver_binding_node = environment_response['environmentDriverBindings']['nodes'].first
      expect(driver_binding_node).to include(a_graphql_entity_for(driver_binding, :version, :driver_ref).to_hash)
      expect(driver_binding_node['environment']).to match(a_graphql_entity_for(environment))
    end

    it 'resolves service environment healths and their parent associations' do
      post_query

      health_node = environment_response['serviceEnvironmentHealths']['nodes'].first
      expect(health_node).to include(a_graphql_entity_for(service_environment_health).to_hash)
      expect(health_node['service']).to match(a_graphql_entity_for(service))
      expect(health_node['environment']).to match(a_graphql_entity_for(environment))
    end

    it 'resolves rollout environments and their rollout' do
      post_query

      rollout_environment_node = environment_response['rolloutEnvironments']['nodes'].first
      expect(rollout_environment_node).to include(a_graphql_entity_for(rollout_environment, :position).to_hash)
      expect(rollout_environment_node['rollout']).to match(a_graphql_entity_for(rollout))
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }

    it 'does not return the environments' do
      post_query

      expect(graphql_dig_at(graphql_data, :organization, :cd_environments, :nodes)).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the environments' do
      post_query

      expect(graphql_dig_at(graphql_data, :organization, :cd_environments, :nodes)).to be_nil
    end
  end
end
