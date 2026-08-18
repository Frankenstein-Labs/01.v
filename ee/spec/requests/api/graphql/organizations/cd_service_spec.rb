# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cd_service', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:other_organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:other_org_application) { create(:cd_application, organization: other_organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:other_org_service) { create(:cd_service, application: other_org_application) }
  let_it_be(:artifact_source) { create(:cd_artifact_source, service: service) }
  let_it_be(:environment) { create(:cd_environment, organization: organization) }
  let_it_be(:service_environment_health) do
    create(:cd_service_environment_health, service: service, environment: environment, health: :healthy)
  end

  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:current_user) { organization_owner }
  let(:service_gid) { service.to_global_id.to_s }

  let(:query) do
    <<~QUERY
      query organizationCdService(
        $id: OrganizationsOrganizationID!,
        $serviceId: CdServiceID!
      ) {
        organization(id: $id) {
          cdService(id: $serviceId) {
            id
            name
            description
            application { id name }
            createdAt
            updatedAt
            artifactSources {
              nodes {
                id
                sourceRef
              }
            }
            serviceEnvironmentHealths {
              nodes {
                id
                health
                environment { id }
                deployedVersions {
                  nodes {
                    id
                    name
                  }
                }
              }
            }
            lastDeployedAt
          }
        }
      }
    QUERY
  end

  subject(:post_query) do
    post_graphql(
      query,
      current_user: current_user,
      variables: { id: organization.to_global_id.to_s, serviceId: service_gid }
    )
  end

  context 'when the user is an organization owner' do
    it 'returns the service with its details', :aggregate_failures do
      post_query

      expect(service_response).to a_graphql_entity_for(service, :name, :description)
      expect(service_response['application']).to a_graphql_entity_for(application, :name)
      expect(service_response['createdAt']).to be_present
      expect(service_response['updatedAt']).to be_present
    end

    it 'returns the artifact sources belonging to the service' do
      post_query

      expect(service_response.dig('artifactSources', 'nodes')).to contain_exactly(
        a_graphql_entity_for(artifact_source, :source_ref)
      )
    end

    it 'returns the service environment healths' do
      post_query

      expect(service_response.dig('serviceEnvironmentHealths', 'nodes')).to contain_exactly(
        a_graphql_entity_for(service_environment_health)
      )
    end

    it 'returns the versions deployed for the service in each environment' do
      version = create(:cd_version, artifact_source: artifact_source)
      version_set = create(:cd_version_set, application: application)
      create(:cd_version_set_entry, version_set: version_set, version: version)
      rollout = create(:cd_rollout, version_set: version_set, application: application)
      rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: environment)
      create(:cd_deployment, service: service, rollout_environment: rollout_environment)

      post_query

      health_node = service_response.dig('serviceEnvironmentHealths', 'nodes').first
      expect(health_node.dig('deployedVersions', 'nodes')).to contain_exactly(
        a_graphql_entity_for(version, :name)
      )
    end

    it 'returns no deployed versions when the environment has no deployment for the service' do
      post_query

      health_node = service_response.dig('serviceEnvironmentHealths', 'nodes').first
      expect(health_node.dig('deployedVersions', 'nodes')).to eq([])
    end

    it 'returns the timestamp of the most recently finished deployment for the service' do
      rollout_environment = create(:cd_rollout_environment)
      older = create(:cd_deployment, service: service, rollout_environment: rollout_environment,
        state: :healthy, finished_at: 2.hours.ago)
      newer = create(:cd_deployment, service: service, state: :healthy, finished_at: 1.hour.ago)

      post_query

      expect(Time.zone.parse(service_response['lastDeployedAt'])).to be_within(1.second).of(newer.finished_at)
      expect(Time.zone.parse(service_response['lastDeployedAt'])).not_to be_within(1.second).of(older.finished_at)
    end

    context 'when the service has no deployments' do
      it 'returns nil for lastDeployedAt' do
        post_query

        expect(service_response['lastDeployedAt']).to be_nil
      end
    end

    context 'when the service belongs to a different organization' do
      let(:service_gid) { other_org_service.to_global_id.to_s }

      it 'returns nil' do
        post_query

        expect(service_response).to be_nil
      end
    end

    it 'avoids N+1 queries when fetching the service with its associations' do
      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s, serviceId: service_gid })
      end

      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      create(:cd_artifact_source, service: service)
      create(:cd_service_environment_health,
        service: service,
        environment: create(:cd_environment, organization: organization))

      expect { run_query.call }.not_to exceed_query_limit(control)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_cd_service, :read_cd_application, :read_cd_artifact_source, :read_cd_environment, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s, serviceId: service.to_global_id.to_s },
          token: { personal_access_token: pat }
        )
      end
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }

    it 'does not return the service' do
      post_query

      expect(service_response).to be_nil
    end
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { non_member }

    it 'does not return the service' do
      post_query

      expect(service_response).to be_nil
    end
  end

  context 'when the request is unauthenticated' do
    let(:current_user) { nil }

    it 'does not return the service' do
      post_query

      expect(service_response).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the service' do
      post_query

      expect(service_response).to be_nil
    end
  end

  def service_response
    graphql_dig_at(graphql_data, :organization, :cd_service)
  end
end
