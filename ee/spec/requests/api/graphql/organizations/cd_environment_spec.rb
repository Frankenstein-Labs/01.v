# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cd_environment', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:other_organization) { create(:organization) }
  let_it_be(:environment) { create(:cd_environment, organization: organization) }
  let_it_be(:other_org_environment) { create(:cd_environment, organization: other_organization) }
  let_it_be(:driver_binding) do
    create(:cd_environment_driver_binding,
      environment: environment,
      driver_config: { 'cluster_agent_id' => 'eks-eu-west-1' })
  end

  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:service_environment_health) do
    create(:cd_service_environment_health, service: service, environment: environment)
  end

  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:rollout) { create(:cd_rollout, version_set: version_set, application: application) }
  let_it_be(:rollout_environment) do
    create(:cd_rollout_environment, rollout: rollout, environment: environment, driver_binding: driver_binding)
  end

  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:current_user) { organization_owner }
  let(:environment_gid) { environment.to_global_id.to_s }

  let(:query) do
    <<~QUERY
      query organizationCdEnvironment(
        $id: OrganizationsOrganizationID!,
        $environmentId: CdEnvironmentID!
      ) {
        organization(id: $id) {
          cdEnvironment(id: $environmentId) {
            id
            name
            description
            organization { id }
            createdAt
            updatedAt
            environmentDriverBindings {
              nodes {
                id
                version
                driverRef
                driverConfig
              }
            }
            serviceEnvironmentHealths {
              nodes {
                id
                health
                service { id }
              }
            }
            rolloutEnvironments {
              nodes {
                id
                position
                state
                rollout { id }
              }
            }
          }
        }
      }
    QUERY
  end

  subject(:post_query) do
    post_graphql(
      query,
      current_user: current_user,
      variables: { id: organization.to_global_id.to_s, environmentId: environment_gid }
    )
  end

  context 'when the user is an organization owner' do
    it 'returns the environment with its details', :aggregate_failures do
      post_query

      expect(environment_response).to a_graphql_entity_for(environment, :name, :description)
      expect(environment_response['organization']).to a_graphql_entity_for(organization)
      expect(environment_response['createdAt']).to be_present
      expect(environment_response['updatedAt']).to be_present
    end

    it 'returns the driver bindings of the environment' do
      post_query

      expect(environment_response.dig('environmentDriverBindings', 'nodes')).to contain_exactly(
        a_graphql_entity_for(driver_binding, :version, driver_ref: driver_binding.driver_ref)
      )
    end

    it 'returns the driver config of the driver bindings' do
      post_query

      driver_binding_node = environment_response.dig('environmentDriverBindings', 'nodes').first

      expect(driver_binding_node['driverConfig']).to eq(driver_binding.driver_config)
    end

    it 'returns the service environment healths' do
      post_query

      expect(environment_response.dig('serviceEnvironmentHealths', 'nodes')).to contain_exactly(
        a_graphql_entity_for(service_environment_health)
      )
    end

    it 'returns the rollout environments of the environment' do
      post_query

      expect(environment_response.dig('rolloutEnvironments', 'nodes')).to contain_exactly(
        a_graphql_entity_for(rollout_environment, :position)
      )
    end

    context 'when the environment belongs to a different organization' do
      let(:environment_gid) { other_org_environment.to_global_id.to_s }

      it 'returns nil' do
        post_query

        expect(environment_response).to be_nil
      end
    end

    it 'avoids N+1 queries when fetching the environment with its associations' do
      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s, environmentId: environment_gid })
      end

      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      3.times { create(:cd_environment_driver_binding, environment: environment) }
      3.times do
        create(:cd_service_environment_health,
          service: create(:cd_service, application: application),
          environment: environment)
      end
      3.times do
        other_rollout = create(:cd_rollout, version_set: version_set, application: application,
          state: :completed, workflow_ref: 'ref')
        create(:cd_rollout_environment, rollout: other_rollout, environment: environment)
      end

      expect { run_query.call }.not_to exceed_query_limit(control)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_cd_environment, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s, environmentId: environment.to_global_id.to_s },
          token: { personal_access_token: pat }
        )
      end
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }

    it 'does not return the environment' do
      post_query

      expect(environment_response).to be_nil
    end
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { non_member }

    it 'does not return the environment' do
      post_query

      expect(environment_response).to be_nil
    end
  end

  context 'when the request is unauthenticated' do
    let(:current_user) { nil }

    it 'does not return the environment' do
      post_query

      expect(environment_response).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the environment' do
      post_query

      expect(environment_response).to be_nil
    end
  end

  def environment_response
    graphql_dig_at(graphql_data, :organization, :cd_environment)
  end
end
