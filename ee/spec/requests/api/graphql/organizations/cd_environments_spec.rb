# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cd_environments', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:other_organization) { create(:organization) }
  let_it_be(:org_environment) { create(:cd_environment, :production, organization: organization) }
  let_it_be(:org_staging_environment) { create(:cd_environment, :staging, organization: organization) }
  let_it_be(:other_org_environment) { create(:cd_environment, organization: other_organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:current_user) { organization_owner }
  let(:tier) { nil }

  let(:query) do
    <<~QUERY
      query organizationCdEnvironments($id: OrganizationsOrganizationID!, $tier: CdEnvironmentTier) {
        organization(id: $id) {
          id
          cdEnvironments(tier: $tier) {
            nodes {
              id
              name
              organization { id }
            }
          }
        }
      }
    QUERY
  end

  subject(:post_query) do
    post_graphql(query, current_user: current_user,
      variables: { id: organization.to_global_id.to_s, tier: tier })
  end

  context 'when the user is an organization owner' do
    it 'returns environments attached to the organization' do
      post_query

      expect(environments_response).to contain_exactly(
        a_graphql_entity_for(org_environment, :name),
        a_graphql_entity_for(org_staging_environment, :name)
      )
    end

    it 'exposes the parent organization for each environment' do
      post_query

      org_env_response = environments_response.find { |env| env['name'] == org_environment.name }

      expect(org_env_response).to include('organization' => a_graphql_entity_for(organization))
    end

    context 'when filtering by tier' do
      let(:tier) { 'PRODUCTION' }

      it 'returns only environments matching the tier' do
        post_query

        expect(environments_response).to contain_exactly(
          a_graphql_entity_for(org_environment, :name)
        )
      end
    end

    context 'when filtering by a tier with no matching environments' do
      let(:tier) { 'DEVELOPMENT' }

      it 'returns an empty list' do
        post_query

        expect(environments_response).to be_empty
      end
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_cd_environment, :read_organization] do
      let_it_be(:granular_organization) { create(:organization) }
      let_it_be(:granular_environment) do
        create(:cd_environment, organization: granular_organization)
      end

      let(:user) { create(:organization_user, :owner, organization: granular_organization).user }
      let(:boundary_object) { :instance }
      let(:query) do
        <<~QUERY
          query organizationCdEnvironments($id: OrganizationsOrganizationID!) {
            organization(id: $id) {
              cdEnvironments { nodes { name } }
            }
          }
        QUERY
      end

      let(:request) do
        post_graphql(query, variables: { id: granular_organization.to_global_id.to_s },
          token: { personal_access_token: pat })
      end
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_cd_environment, :read_organization] do
      let_it_be(:granular_organization) { create(:organization) }
      let_it_be(:granular_environment) do
        create(:cd_environment, organization: granular_organization)
      end

      let_it_be(:granular_application) { create(:cd_application, organization: granular_organization) }
      let_it_be(:granular_service_health) do
        create(:cd_service_environment_health,
          service: create(:cd_service, application: granular_application), environment: granular_environment)
      end

      let(:user) { create(:organization_user, :owner, organization: granular_organization).user }
      let(:boundary_object) { :instance }
      let(:query) do
        <<~QUERY
          query organizationCdEnvironments($id: OrganizationsOrganizationID!) {
            organization(id: $id) {
              cdEnvironments { nodes { applications { nodes { servicesCount } } } }
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

  describe 'applicationsCount' do
    let(:applications_count_query) do
      <<~QUERY
        query organizationCdEnvironments($id: OrganizationsOrganizationID!) {
          organization(id: $id) {
            cdEnvironments { nodes { name applicationsCount } }
          }
        }
      QUERY
    end

    let(:run_query) do
      -> do
        post_graphql(applications_count_query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s })
      end
    end

    before_all do
      app_a = create(:cd_application, organization: organization)
      app_b = create(:cd_application, organization: organization)
      create(:cd_service_environment_health, service: create(:cd_service, application: app_a),
        environment: org_environment)
      create(:cd_service_environment_health, service: create(:cd_service, application: app_a),
        environment: org_environment)
      create(:cd_service_environment_health, service: create(:cd_service, application: app_b),
        environment: org_environment)
    end

    it 'returns the distinct application count for each environment' do
      run_query.call

      prod = environments_response.find { |env| env['name'] == org_environment.name }
      staging = environments_response.find { |env| env['name'] == org_staging_environment.name }

      expect(prod['applicationsCount']).to eq(2)
      expect(staging['applicationsCount']).to eq(0)
    end

    it 'does not run an extra query per environment (no N+1)' do
      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      extra_environment = create(:cd_environment, organization: organization)
      create(:cd_service_environment_health,
        service: create(:cd_service, application: create(:cd_application, organization: organization)),
        environment: extra_environment)

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  describe 'applications' do
    let(:applications_query) do
      <<~QUERY
        query organizationCdEnvironments($id: OrganizationsOrganizationID!) {
          organization(id: $id) {
            cdEnvironments {
              nodes {
                name
                applications {
                  nodes {
                    servicesCount
                    application { name }
                    serviceEnvironmentHealths {
                      nodes { service { name } deployedVersions { nodes { name } } }
                    }
                  }
                }
              }
            }
          }
        }
      QUERY
    end

    let(:run_query) do
      -> do
        post_graphql(applications_query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s })
      end
    end

    let_it_be(:zebra_app) { create(:cd_application, organization: organization, name: 'zebra-app') }
    let_it_be(:alpha_app) { create(:cd_application, organization: organization, name: 'alpha-app') }
    let_it_be(:alpha_api) { create(:cd_service, application: alpha_app, name: 'api') }
    let_it_be(:alpha_worker) { create(:cd_service, application: alpha_app, name: 'worker') }
    let_it_be(:zebra_web) { create(:cd_service, application: zebra_app, name: 'web') }
    let_it_be(:api_version) do
      create(:cd_version, artifact_source: create(:cd_artifact_source, service: alpha_api), name: 'v4-2-0')
    end

    before_all do
      create(:cd_service_environment_health, service: alpha_api, environment: org_environment)
      create(:cd_service_environment_health, service: alpha_worker, environment: org_environment)
      create(:cd_service_environment_health, service: zebra_web, environment: org_environment)

      version_set = create(:cd_version_set, application: alpha_app)
      create(:cd_version_set_entry, version_set: version_set, version: api_version)
      rollout = create(:cd_rollout, version_set: version_set, application: alpha_app)
      rollout_environment = create(:cd_rollout_environment, rollout: rollout, environment: org_environment)
      create(:cd_deployment, service: alpha_api, rollout_environment: rollout_environment, started_at: Time.current)
    end

    it 'returns each application with its services and their deployed versions, ordered by name' do
      run_query.call

      prod = environments_response.find { |env| env['name'] == org_environment.name }

      expect(prod.dig('applications', 'nodes')).to eq([
        {
          'servicesCount' => 2,
          'application' => { 'name' => 'alpha-app' },
          'serviceEnvironmentHealths' => { 'nodes' => [
            { 'service' => { 'name' => 'api' }, 'deployedVersions' => { 'nodes' => [{ 'name' => 'v4-2-0' }] } },
            { 'service' => { 'name' => 'worker' }, 'deployedVersions' => { 'nodes' => [] } }
          ] }
        },
        {
          'servicesCount' => 1,
          'application' => { 'name' => 'zebra-app' },
          'serviceEnvironmentHealths' => { 'nodes' => [
            { 'service' => { 'name' => 'web' }, 'deployedVersions' => { 'nodes' => [] } }
          ] }
        }
      ])
    end

    it 'does not run extra queries per application, service, or deployed version (no N+1)' do
      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      create(:cd_service_environment_health,
        service: create(:cd_service, application: create(:cd_application, organization: organization)),
        environment: org_environment)
      create(:cd_service_environment_health, service: create(:cd_service, application: alpha_app),
        environment: org_environment)

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  describe 'servicesCount' do
    let(:services_count_query) do
      <<~QUERY
        query organizationCdEnvironments($id: OrganizationsOrganizationID!) {
          organization(id: $id) {
            cdEnvironments { nodes { name servicesCount } }
          }
        }
      QUERY
    end

    let(:run_query) do
      -> do
        post_graphql(services_count_query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s })
      end
    end

    before_all do
      app_a = create(:cd_application, organization: organization)
      app_b = create(:cd_application, organization: organization)
      create(:cd_service_environment_health, service: create(:cd_service, application: app_a),
        environment: org_environment)
      create(:cd_service_environment_health, service: create(:cd_service, application: app_a),
        environment: org_environment)
      create(:cd_service_environment_health, service: create(:cd_service, application: app_b),
        environment: org_environment)
    end

    it 'returns the service count for each environment' do
      run_query.call

      prod = environments_response.find { |env| env['name'] == org_environment.name }
      staging = environments_response.find { |env| env['name'] == org_staging_environment.name }

      expect(prod['servicesCount']).to eq(3)
      expect(staging['servicesCount']).to eq(0)
    end

    it 'does not run an extra query per environment (no N+1)' do
      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      extra_environment = create(:cd_environment, organization: organization)
      create(:cd_service_environment_health,
        service: create(:cd_service, application: create(:cd_application, organization: organization)),
        environment: extra_environment)

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  describe 'search' do
    let_it_be(:payments_env) do
      create(:cd_environment, organization: organization, name: 'payments-prod', description: 'Payments production')
    end

    let(:search_query) do
      <<~QUERY
        query organizationCdEnvironments($id: OrganizationsOrganizationID!, $search: String) {
          organization(id: $id) {
            cdEnvironments(search: $search) { nodes { name } }
          }
        }
      QUERY
    end

    let(:run_query) do
      -> do
        post_graphql(search_query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s, search: 'payments' })
      end
    end

    it 'returns only environments matching the search term' do
      run_query.call

      expect(environments_response.pluck('name')).to contain_exactly(payments_env.name)
    end

    it 'does not run an extra query per environment (no N+1)' do
      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      create(:cd_environment, organization: organization, name: 'payments-staging', description: 'Payments staging')

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }

    it 'does not return the environments' do
      post_query

      expect(environments_response).to be_nil
    end
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { non_member }

    it 'does not return the environments' do
      post_query

      expect(environments_response).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the environments' do
      post_query

      expect(environments_response).to be_nil
    end
  end

  def environments_response
    graphql_dig_at(graphql_data, :organization, :cd_environments, :nodes)
  end
end
