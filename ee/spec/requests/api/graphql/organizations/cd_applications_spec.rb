# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cd_applications', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:other_organization) { create(:organization) }
  let_it_be(:org_application) { create(:cd_application, organization: organization) }
  let_it_be(:other_org_application) { create(:cd_application, organization: other_organization) }
  let_it_be(:org_application_service_a) { create(:cd_service, application: org_application) }
  let_it_be(:org_application_service_b) { create(:cd_service, application: org_application) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:current_user) { organization_owner }

  let(:query) do
    <<~QUERY
      query organizationCdApplications($id: OrganizationsOrganizationID!) {
        organization(id: $id) {
          id
          cdApplications {
            nodes {
              id
              name
              organization { id }
              services {
                nodes {
                  id
                  name
                  description
                }
              }
            }
          }
        }
      }
    QUERY
  end

  subject(:post_query) do
    post_graphql(query, current_user: current_user, variables: { id: organization.to_global_id.to_s })
  end

  context 'when the user is an organization owner' do
    it 'returns applications attached to the organization' do
      post_query

      expect(applications_response).to contain_exactly(
        a_graphql_entity_for(org_application, :name)
      )
    end

    it 'exposes the parent organization for each application' do
      post_query

      org_app_response = applications_response.find { |app| app['name'] == org_application.name }

      expect(org_app_response).to include('organization' => a_graphql_entity_for(organization))
    end

    it 'returns services belonging to the application' do
      post_query

      org_app_response = applications_response.find { |app| app['name'] == org_application.name }

      expect(org_app_response['services']['nodes']).to contain_exactly(
        a_graphql_entity_for(org_application_service_a, :name, :description),
        a_graphql_entity_for(org_application_service_b, :name, :description)
      )
    end

    it 'avoids N+1 queries when fetching services across applications' do
      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s })
      end

      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      extra_application = create(:cd_application, organization: organization)
      create(:cd_service, application: extra_application)

      expect { run_query.call }.not_to exceed_query_limit(control)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_cd_application, :read_organization] do
      let_it_be(:granular_organization) { create(:organization) }
      let_it_be(:granular_application) do
        create(:cd_application, organization: granular_organization)
      end

      let(:user) { create(:organization_user, :owner, organization: granular_organization).user }
      let(:boundary_object) { :instance }
      let(:query) do
        <<~QUERY
          query organizationCdApplications($id: OrganizationsOrganizationID!) {
            organization(id: $id) {
              cdApplications { nodes { name } }
            }
          }
        QUERY
      end

      let(:request) do
        post_graphql(query, variables: { id: granular_organization.to_global_id.to_s },
          token: { personal_access_token: pat })
      end
    end
  end

  describe 'health rollup' do
    let(:query) do
      <<~QUERY
        query organizationCdApplications($id: OrganizationsOrganizationID!) {
          organization(id: $id) {
            cdApplications { nodes { name health } }
          }
        }
      QUERY
    end

    def health_response
      org_app = applications_response.find { |app| app['name'] == org_application.name }
      org_app['health']
    end

    it 'returns the worst health observed across the application services' do
      environment = create(:cd_environment, organization: organization)
      other_environment = create(:cd_environment, organization: organization)
      create(:cd_service_environment_health,
        service: org_application_service_a, environment: environment, health: :healthy)
      create(:cd_service_environment_health,
        service: org_application_service_b, environment: other_environment, health: :degraded)

      post_query

      expect(health_response).to eq('DEGRADED')
    end

    it 'returns null when no health has been reported' do
      post_query

      expect(health_response).to be_nil
    end

    it 'avoids N+1 queries when resolving health across applications' do
      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s })
      end

      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      extra_application = create(:cd_application, organization: organization)
      extra_service = create(:cd_service, application: extra_application)
      create(:cd_service_environment_health,
        service: extra_service, environment: create(:cd_environment, organization: organization), health: :failed)

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  describe 'status rollup' do
    let(:query) do
      <<~QUERY
        query organizationCdApplications($id: OrganizationsOrganizationID!) {
          organization(id: $id) {
            cdApplications { nodes { name status } }
          }
        }
      QUERY
    end

    def status_response
      org_app = applications_response.find { |app| app['name'] == org_application.name }
      org_app['status']
    end

    it 'returns degraded when the worst service health is degraded' do
      create(:cd_service_environment_health, service: org_application_service_a,
        environment: create(:cd_environment, organization: organization), health: :degraded)

      post_query

      expect(status_response).to eq('DEGRADED')
    end

    it 'returns deploying when the application has a rollout in progress' do
      create(:cd_rollout, version_set: create(:cd_version_set, application: org_application),
        state: :in_progress, workflow_ref: 'workflow-1')

      post_query

      expect(status_response).to eq('DEPLOYING')
    end

    it 'returns null when no health has been reported and no rollout is in progress' do
      post_query

      expect(status_response).to be_nil
    end

    it 'avoids N+1 queries when resolving status across applications' do
      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s })
      end

      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      extra_application = create(:cd_application, organization: organization)
      extra_service = create(:cd_service, application: extra_application)
      create(:cd_service_environment_health,
        service: extra_service, environment: create(:cd_environment, organization: organization), health: :degraded)

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  describe 'filtering by status' do
    let_it_be(:healthy_app) { create(:cd_application, organization: organization) }
    let_it_be(:degraded_app) { create(:cd_application, organization: organization) }
    let_it_be(:deploying_app) { create(:cd_application, organization: organization) }
    let_it_be(:environment) { create(:cd_environment, organization: organization) }

    let(:query) do
      <<~QUERY
        query organizationCdApplications($id: OrganizationsOrganizationID!, $statuses: [CdApplicationStatus!]) {
          organization(id: $id) {
            cdApplications(statuses: $statuses) { nodes { name } }
          }
        }
      QUERY
    end

    before_all do
      healthy_service = create(:cd_service, application: healthy_app)
      create(:cd_service_environment_health, service: healthy_service, environment: environment, health: :healthy)

      degraded_service = create(:cd_service, application: degraded_app)
      create(:cd_service_environment_health, service: degraded_service, environment: environment, health: :degraded)

      create(:cd_rollout, version_set: create(:cd_version_set, application: deploying_app),
        state: :in_progress, workflow_ref: 'workflow-1')
    end

    subject(:post_query) do
      post_graphql(query, current_user: current_user,
        variables: { id: organization.to_global_id.to_s, statuses: statuses })
    end

    def application_names
      applications_response.pluck('name')
    end

    context 'with HEALTHY' do
      let(:statuses) { ['HEALTHY'] }

      it 'returns only applications whose worst health is healthy' do
        post_query

        expect(application_names).to contain_exactly(healthy_app.name)
      end
    end

    context 'with DEGRADED' do
      let(:statuses) { ['DEGRADED'] }

      it 'returns only applications whose worst health is degraded' do
        post_query

        expect(application_names).to contain_exactly(degraded_app.name)
      end
    end

    context 'with DEPLOYING' do
      let(:statuses) { ['DEPLOYING'] }

      it 'returns only applications with a rollout in progress' do
        post_query

        expect(application_names).to contain_exactly(deploying_app.name)
      end
    end

    context 'with AWAITING_APPROVAL' do
      let(:statuses) { ['AWAITING_APPROVAL'] }

      it 'returns an empty collection, since it has no backend representation yet' do
        post_query

        expect(applications_response).to be_empty
      end
    end

    context 'with multiple statuses' do
      let(:statuses) { %w[DEGRADED DEPLOYING AWAITING_APPROVAL] }

      it 'returns applications matching any backed status and ignores unbacked ones' do
        post_query

        expect(application_names).to contain_exactly(degraded_app.name, deploying_app.name)
      end
    end

    it 'does not add queries per matching application (no N+1)' do
      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s, statuses: ['DEGRADED'] })
      end

      run_query.call

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      extra_app = create(:cd_application, organization: organization)
      extra_service = create(:cd_service, application: extra_app)
      create(:cd_service_environment_health, service: extra_service, environment: environment, health: :degraded)

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  describe 'searching by name or description' do
    let_it_be(:payments_application) do
      create(:cd_application, organization: organization, name: 'payments-platform',
        description: 'Billing system')
    end

    let(:query) do
      <<~QUERY
        query organizationCdApplications($id: OrganizationsOrganizationID!, $search: String) {
          organization(id: $id) {
            cdApplications(search: $search) { nodes { name } }
          }
        }
      QUERY
    end

    subject(:post_query) do
      post_graphql(query, current_user: current_user,
        variables: { id: organization.to_global_id.to_s, search: search })
    end

    def application_names
      applications_response.pluck('name')
    end

    context 'when the term matches a name' do
      let(:search) { 'payments' }

      it 'returns only matching applications' do
        post_query

        expect(application_names).to contain_exactly(payments_application.name)
      end
    end

    context 'when the term matches a description' do
      let(:search) { 'billing' }

      it 'returns only matching applications' do
        post_query

        expect(application_names).to contain_exactly(payments_application.name)
      end
    end

    it 'does not add queries per matching application (no N+1)' do
      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s, search: 'app' })
      end

      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      create(:cd_application, organization: organization, name: 'another-app', description: 'app')

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  describe 'last deployed at rollup' do
    let(:query) do
      <<~QUERY
        query organizationCdApplications($id: OrganizationsOrganizationID!) {
          organization(id: $id) {
            cdApplications {
              nodes {
                name
                services {
                  nodes { name lastDeployedAt }
                }
              }
            }
          }
        }
      QUERY
    end

    def service_response(service)
      org_app = applications_response.find { |app| app['name'] == org_application.name }
      org_app['services']['nodes'].find { |node| node['name'] == service.name }
    end

    it 'returns the timestamp of the most recently finished deployment for each service' do
      older = create(:cd_deployment, service: org_application_service_a, state: :healthy, finished_at: 2.hours.ago)
      newer = create(:cd_deployment, service: org_application_service_a, state: :healthy, finished_at: 1.hour.ago)

      post_query

      last_deployed_at = Time.zone.parse(service_response(org_application_service_a)['lastDeployedAt'])
      expect(last_deployed_at).to be_within(1.second).of(newer.finished_at)
      expect(last_deployed_at).not_to be_within(1.second).of(older.finished_at)
    end

    it 'returns null when the service has no finished deployment' do
      post_query

      expect(service_response(org_application_service_b)['lastDeployedAt']).to be_nil
    end

    it 'avoids N+1 queries when resolving last deployed at across services' do
      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s })
      end

      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      extra_application = create(:cd_application, organization: organization)
      extra_service = create(:cd_service, application: extra_application)
      create(:cd_deployment, service: extra_service, state: :healthy, finished_at: 1.hour.ago)

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }

    it 'does not return the applications' do
      post_query

      expect(applications_response).to be_nil
    end
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { non_member }

    it 'does not return the applications' do
      post_query

      expect(applications_response).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the applications' do
      post_query

      expect(applications_response).to be_nil
    end
  end

  def applications_response
    graphql_dig_at(graphql_data, :organization, :cd_applications, :nodes)
  end
end
