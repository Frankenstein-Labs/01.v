# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cd_application', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:other_organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:other_application) { create(:cd_application, organization: other_organization) }

  let_it_be(:service_a) { create(:cd_service, application: application) }
  let_it_be(:service_b) { create(:cd_service, application: application) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:current_user) { organization_owner }
  let(:application_gid) { application.to_global_id.to_s }

  let(:query) do
    <<~QUERY
      query organizationCdApplication(
        $id: OrganizationsOrganizationID!,
        $applicationId: CdApplicationID!
      ) {
        organization(id: $id) {
          cdApplication(id: $applicationId) {
            id
            name
            description
            organization { id }
            createdAt
            updatedAt
            services {
              nodes {
                id
                name
                description
              }
            }
            environments {
              nodes {
                id
                name
              }
            }
            deployments {
              nodes {
                id
                state
              }
            }
            lastDeployedAt
            userPermissions {
              readCdApplication
              updateCdApplication
              createCdService
              updateCdService
              createCdVersionSet
              createCdRollout
              resolveCdRolloutGate
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
      variables: { id: organization.to_global_id.to_s, applicationId: application_gid }
    )
  end

  context 'when the user is an organization owner' do
    it 'returns the application with its details', :aggregate_failures do
      post_query

      expect(application_response).to a_graphql_entity_for(application, :name, :description)
      expect(application_response['organization']).to a_graphql_entity_for(organization)
      expect(application_response['createdAt']).to be_present
      expect(application_response['updatedAt']).to be_present
    end

    it 'returns the services belonging to the application' do
      post_query

      expect(application_response.dig('services', 'nodes')).to contain_exactly(
        a_graphql_entity_for(service_a, :name, :description),
        a_graphql_entity_for(service_b, :name, :description)
      )
    end

    it 'returns the distinct environments the application has rolled out to' do
      staging = create(:cd_environment, :staging, organization: organization)
      version_set = create(:cd_version_set, application: application)
      rollout = create(:cd_rollout, version_set: version_set, application: application)
      create(:cd_rollout_environment, rollout: rollout, environment: staging)

      post_query

      expect(application_response.dig('environments', 'nodes')).to contain_exactly(
        a_graphql_entity_for(staging, :name)
      )
    end

    context 'when the application belongs to a different organization' do
      let(:application_gid) { other_application.to_global_id.to_s }

      it 'returns nil' do
        post_query

        expect(application_response).to be_nil
      end
    end

    it 'returns the deployments actuated by the application and the last deployed timestamp' do
      environment = create(:cd_environment, organization: organization)
      version_set = create(:cd_version_set, application: application)
      rollout = create(:cd_rollout, version_set: version_set, application: application)
      rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: environment)
      deployment = create(:cd_deployment, service: service_a, rollout_environment: rollout_environment,
        state: :healthy, finished_at: 1.hour.ago)

      post_query

      expect(application_response.dig('deployments', 'nodes')).to contain_exactly(
        a_graphql_entity_for(deployment)
      )
      expect(Time.zone.parse(application_response['lastDeployedAt'])).to be_within(1.second).of(deployment.finished_at)
    end

    context 'when the application has no deployments' do
      it 'returns nil for lastDeployedAt' do
        post_query

        expect(application_response['lastDeployedAt']).to be_nil
      end
    end

    it 'returns the user permissions for the application' do
      post_query

      expect(application_response['userPermissions']).to eq(
        'readCdApplication' => true,
        'updateCdApplication' => true,
        'createCdService' => true,
        'updateCdService' => true,
        'createCdVersionSet' => true,
        'createCdRollout' => true,
        'resolveCdRolloutGate' => true
      )
    end

    it 'avoids N+1 queries when fetching the application environments' do
      version_set = create(:cd_version_set, application: application)
      rollout = create(:cd_rollout, version_set: version_set, application: application)
      create(:cd_rollout_environment, rollout: rollout,
        environment: create(:cd_environment, organization: organization))

      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s, applicationId: application_gid })
      end
      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      create(:cd_rollout_environment, rollout: rollout,
        environment: create(:cd_environment, organization: organization))

      expect { run_query.call }.not_to exceed_query_limit(control)
    end

    it 'avoids N+1 queries when fetching the application deployments' do
      environment = create(:cd_environment, organization: organization)
      version_set = create(:cd_version_set, application: application)
      rollout = create(:cd_rollout, version_set: version_set, application: application)
      rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: environment)
      create(:cd_deployment, service: service_a, rollout_environment: rollout_environment)

      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s, applicationId: application_gid })
      end
      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      create(:cd_deployment, service: service_b, rollout_environment: rollout_environment)

      expect { run_query.call }.not_to exceed_query_limit(control)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_cd_application, :read_cd_service, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s, applicationId: application.to_global_id.to_s },
          token: { personal_access_token: pat }
        )
      end
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }

    it 'does not return the application' do
      post_query

      expect(application_response).to be_nil
    end
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { non_member }

    it 'does not return the application' do
      post_query

      expect(application_response).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the application' do
      post_query

      expect(application_response).to be_nil
    end
  end

  describe 'searching services and version sets' do
    let_it_be(:api_service) { create(:cd_service, application: application, name: 'payments-api') }
    let_it_be(:worker_service) { create(:cd_service, application: application, name: 'reporting-worker') }
    let_it_be(:payments_release) { create(:cd_version_set, application: application, name: 'payments-2-4') }
    let_it_be(:web_release) { create(:cd_version_set, application: application, name: 'web-3-0') }

    let(:query) do
      <<~QUERY
        query organizationCdApplication($id: OrganizationsOrganizationID!, $applicationId: CdApplicationID!) {
          organization(id: $id) {
            cdApplication(id: $applicationId) {
              services(search: "payments") { nodes { name } }
              versionSets(search: "web") { nodes { name } }
            }
          }
        }
      QUERY
    end

    it 'filters services and version sets by the search term' do
      post_query

      expect(application_response.dig('services', 'nodes').pluck('name')).to contain_exactly('payments-api')
      expect(application_response.dig('versionSets', 'nodes').pluck('name')).to contain_exactly('web-3-0')
    end
  end

  describe 'filtering rollouts by status' do
    let_it_be(:version_set) { create(:cd_version_set, application: application) }

    # Only one non-terminal (pending/in_progress/paused) rollout is allowed per
    # application at a time (see index_cd_rollouts_on_application_id_non_terminal),
    # so only one active-bucket rollout is created here; terminal-state rollouts
    # have no such restriction.
    let_it_be(:active_rollout) do
      create(:cd_rollout, version_set: version_set, application: application, state: :in_progress,
        workflow_ref: 'wk:1/abc')
    end

    let_it_be(:completed_rollout) do
      create(:cd_rollout, version_set: version_set, application: application, state: :completed,
        workflow_ref: 'wk:1/abc')
    end

    let_it_be(:failed_rollout) do
      create(:cd_rollout, version_set: version_set, application: application, state: :failed,
        workflow_ref: 'wk:1/abc')
    end

    let(:query) do
      <<~QUERY
        query organizationCdApplication($id: OrganizationsOrganizationID!, $applicationId: CdApplicationID!) {
          organization(id: $id) {
            cdApplication(id: $applicationId) {
              rollouts(statuses: #{statuses}) { nodes { id state } }
            }
          }
        }
      QUERY
    end

    context 'when a single status is given' do
      let(:statuses) { '[ACTIVE]' }

      it 'returns only rollouts in the states grouped under that status' do
        post_query

        expect(application_response.dig('rollouts', 'nodes')).to contain_exactly(
          a_graphql_entity_for(active_rollout)
        )
      end
    end

    context 'when multiple statuses are given' do
      let(:statuses) { '[SUCCEEDED, FAILED]' }

      it 'returns rollouts in the states grouped under any of the given statuses' do
        post_query

        expect(application_response.dig('rollouts', 'nodes')).to contain_exactly(
          a_graphql_entity_for(completed_rollout),
          a_graphql_entity_for(failed_rollout)
        )
      end
    end

    context 'when no statuses are given' do
      let(:statuses) { '[]' }

      it 'returns all rollouts' do
        post_query

        expect(application_response.dig('rollouts', 'nodes')).to contain_exactly(
          a_graphql_entity_for(active_rollout),
          a_graphql_entity_for(completed_rollout),
          a_graphql_entity_for(failed_rollout)
        )
      end
    end
  end

  describe 'filtering releases (version sets) by status' do
    let_it_be(:deploying_release) { create(:cd_version_set, application: application) }
    let_it_be(:deploying_rollout) do
      create(:cd_rollout, version_set: deploying_release, application: application, state: :in_progress,
        workflow_ref: 'wk:1/deploying')
    end

    let_it_be(:current_release) { create(:cd_version_set, application: application) }
    let_it_be(:current_rollout) do
      create(:cd_rollout, version_set: current_release, application: application, state: :completed,
        workflow_ref: 'wk:1/current')
    end

    let_it_be(:superseded_release) { create(:cd_version_set, application: application) }
    let_it_be(:superseded_rollout) do
      create(:cd_rollout, version_set: superseded_release, application: application, state: :completed,
        workflow_ref: 'wk:1/superseded')
    end

    let_it_be(:superseding_release) { create(:cd_version_set, application: application) }
    let_it_be(:superseding_rollout) do
      create(:cd_rollout, version_set: superseding_release, application: application, state: :completed,
        workflow_ref: 'wk:1/superseding')
    end

    let_it_be(:superseding_rollout_environment) do
      create(:cd_rollout_environment, rollout: superseding_rollout, state: :completed,
        previous_version_set: superseded_release)
    end

    let(:query) do
      <<~QUERY
        query organizationCdApplication($id: OrganizationsOrganizationID!, $applicationId: CdApplicationID!) {
          organization(id: $id) {
            cdApplication(id: $applicationId) {
              versionSets(statuses: #{statuses}) { nodes { id name status } }
            }
          }
        }
      QUERY
    end

    context 'when a single status is given' do
      let(:statuses) { '[DEPLOYING]' }

      it 'returns only releases with that status' do
        post_query

        expect(application_response.dig('versionSets', 'nodes')).to contain_exactly(
          a_graphql_entity_for(deploying_release, status: 'DEPLOYING')
        )
      end
    end

    context 'when multiple statuses are given' do
      let(:statuses) { '[DEPLOYING, SUPERSEDED]' }

      it 'returns releases matching any of the given statuses' do
        post_query

        expect(application_response.dig('versionSets', 'nodes')).to contain_exactly(
          a_graphql_entity_for(deploying_release, status: 'DEPLOYING'),
          a_graphql_entity_for(superseded_release, status: 'SUPERSEDED')
        )
      end
    end

    context 'when no statuses are given' do
      let(:statuses) { '[]' }

      it 'returns all releases, with status null for releases with no special status' do
        post_query

        expect(application_response.dig('versionSets', 'nodes')).to contain_exactly(
          a_graphql_entity_for(deploying_release, status: 'DEPLOYING'),
          a_graphql_entity_for(current_release, status: nil),
          a_graphql_entity_for(superseded_release, status: 'SUPERSEDED'),
          a_graphql_entity_for(superseding_release, status: nil)
        )
      end

      it 'avoids N+1 queries when resolving the status field across releases' do
        run_query = -> do
          post_graphql(query, current_user: current_user,
            variables: { id: organization.to_global_id.to_s, applicationId: application_gid })
        end
        run_query.call # warm caches

        control = ActiveRecord::QueryRecorder.new { run_query.call }

        extra_release = create(:cd_version_set, application: application)
        create(:cd_rollout, version_set: extra_release, application: application, state: :completed,
          workflow_ref: 'wk:1/extra')

        expect { run_query.call }.not_to exceed_query_limit(control)
      end
    end
  end

  def application_response
    graphql_dig_at(graphql_data, :organization, :cd_application)
  end
end
