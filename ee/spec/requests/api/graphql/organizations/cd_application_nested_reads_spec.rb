# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cdApplications nested reads', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:artifact_source) { create(:cd_artifact_source, service: service) }
  let_it_be(:version) { create(:cd_version, artifact_source: artifact_source) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:version_set_entry) do
    create(:cd_version_set_entry, version_set: version_set, version: version)
  end

  let_it_be(:application_flow_definition) do
    create(:cd_application_flow_definition, application: application)
  end

  let_it_be(:application_link) { create(:cd_application_link, application: application) }

  let_it_be(:environment) { create(:cd_environment, organization: organization) }
  let_it_be(:rollout) do
    create(:cd_rollout, version_set: version_set, application: application,
      application_flow_definition: application_flow_definition)
  end

  let_it_be(:rollout_transition) { create(:cd_rollout_transition, rollout: rollout) }
  let_it_be(:rollout_environment) do
    create(:cd_rollout_environment, rollout: rollout, environment: environment)
  end

  let_it_be(:deployment) do
    create(:cd_deployment, service: service, rollout_environment: rollout_environment)
  end

  let_it_be(:deployment_transition) { create(:cd_deployment_transition, deployment: deployment) }
  let_it_be(:service_environment_health) do
    create(:cd_service_environment_health, service: service, environment: environment)
  end

  let(:current_user) { organization_owner }

  subject(:post_query) do
    post_graphql(query, current_user: current_user, variables: { id: organization.to_global_id.to_s })
  end

  def build_query(selection)
    <<~QUERY
      query organizationCdApplications($id: OrganizationsOrganizationID!) {
        organization(id: $id) {
          cdApplications {
            nodes {
              id
              name
              #{selection}
            }
          }
        }
      }
    QUERY
  end

  def application_response
    graphql_dig_at(graphql_data, :organization, :cd_applications, :nodes).first
  end

  def restore_definition_file(flow_definition)
    flow_definition.file.store!(CarrierWaveStringFile.new(flow_definition.definition))
  end

  context 'when the user is an organization owner' do
    context 'with services' do
      let(:query) do
        build_query(<<~SELECTION)
          services {
            nodes {
              id
              name
              artifactSources {
                nodes {
                  id
                  sourceRef
                  service { id }
                  versions { nodes { id name artifactSource { id } } }
                }
              }
              serviceEnvironmentHealths { nodes { id health service { id } environment { id } } }
            }
          }
        SELECTION
      end

      it 'resolves services and their descendants' do
        post_query

        services = application_response['services']['nodes']
        expect(services).to contain_exactly(a_graphql_entity_for(service, :name))

        service_node = services.first
        artifact_source_node = service_node['artifactSources']['nodes'].first
        expect(artifact_source_node).to include(a_graphql_entity_for(artifact_source, :source_ref).to_hash)
        expect(artifact_source_node['service']).to match(a_graphql_entity_for(service))
        expect(artifact_source_node['versions']['nodes'])
          .to contain_exactly(a_graphql_entity_for(version, :name))
        expect(artifact_source_node['versions']['nodes'].first['artifactSource'])
          .to match(a_graphql_entity_for(artifact_source))

        health_node = service_node['serviceEnvironmentHealths']['nodes'].first
        expect(health_node).to include(a_graphql_entity_for(service_environment_health).to_hash)
        expect(health_node['service']).to match(a_graphql_entity_for(service))
        expect(health_node['environment']).to match(a_graphql_entity_for(environment))
      end
    end

    context 'with service health rollups' do
      let(:query) do
        build_query('services { nodes { id serviceEnvironmentHealths { nodes { health } } } }')
      end

      it 'returns the health observations ordered from worst to best severity' do
        failed_environment = create(:cd_environment, organization: organization)
        create(:cd_service_environment_health, service: service, environment: failed_environment, health: :failed)

        post_query

        service_node = application_response['services']['nodes'].first
        healths = service_node.dig('serviceEnvironmentHealths', 'nodes').pluck('health')

        expect(healths.first).to eq('FAILED')
      end

      it 'avoids N+1 queries as the number of health observations grows' do
        run_query = -> do
          post_graphql(query, current_user: current_user, variables: { id: organization.to_global_id.to_s })
        end

        run_query.call # warm caches

        control = ActiveRecord::QueryRecorder.new { run_query.call }

        create(:cd_service_environment_health,
          service: service,
          environment: create(:cd_environment, organization: organization),
          health: :failed)

        expect { run_query.call }.not_to exceed_query_limit(control)
      end
    end

    context 'with version sets' do
      let(:query) do
        build_query(<<~SELECTION)
          versionSets {
            nodes {
              id
              name
              application { id }
              versionSetEntries {
                nodes {
                  id
                  versionSet { id }
                  version { id artifactSource { id } }
                  artifactSource { id }
                  service { id }
                }
              }
              rollouts { nodes { id state application { id } versionSet { id } } }
            }
          }
        SELECTION
      end

      it 'resolves version sets and their descendants' do
        post_query

        version_sets = application_response['versionSets']['nodes']
        expect(version_sets).to contain_exactly(a_graphql_entity_for(version_set, :name))

        version_set_node = version_sets.first
        expect(version_set_node['application']).to match(a_graphql_entity_for(application))

        entry_node = version_set_node['versionSetEntries']['nodes'].first
        expect(entry_node).to include(a_graphql_entity_for(version_set_entry).to_hash)
        expect(entry_node['versionSet']).to match(a_graphql_entity_for(version_set))
        expect(entry_node['version']).to include(a_graphql_entity_for(version).to_hash)
        expect(entry_node['version']['artifactSource']).to match(a_graphql_entity_for(artifact_source))
        expect(entry_node['artifactSource']).to match(a_graphql_entity_for(artifact_source))
        expect(entry_node['service']).to match(a_graphql_entity_for(service))

        rollout_node = version_set_node['rollouts']['nodes'].first
        expect(rollout_node).to include(a_graphql_entity_for(rollout).to_hash)
        expect(rollout_node['application']).to match(a_graphql_entity_for(application))
        expect(rollout_node['versionSet']).to match(a_graphql_entity_for(version_set))
      end
    end

    context 'with version environments' do
      let(:query) do
        build_query(<<~SELECTION)
          services {
            nodes {
              artifactSources {
                nodes {
                  versions {
                    nodes {
                      id
                      environments { nodes { id name } }
                    }
                  }
                }
              }
            }
          }
        SELECTION
      end

      it 'resolves the distinct environments the version was deployed to' do
        post_query

        service_node = application_response['services']['nodes'].first
        artifact_source_node = service_node['artifactSources']['nodes'].first
        version_node = artifact_source_node['versions']['nodes'].first

        expect(version_node['environments']['nodes']).to contain_exactly(a_graphql_entity_for(environment, :name))
      end

      it 'avoids N+1 queries as the number of versions grows' do
        run_query = -> do
          post_graphql(query, current_user: current_user, variables: { id: organization.to_global_id.to_s })
        end

        run_query.call # warm caches

        control = ActiveRecord::QueryRecorder.new { run_query.call }

        # Another artifact source/version of the same, already-deployed
        # service, which environments must resolve without any additional
        # deployment (see Cd::Version.environments_for).
        other_artifact_source = create(:cd_artifact_source, service: service)
        other_version = create(:cd_version, artifact_source: other_artifact_source)
        create(:cd_version_set_entry, version_set: version_set, version: other_version)

        expect { run_query.call }.not_to exceed_query_limit(control)
      end
    end

    context 'with rollouts' do
      let(:query) do
        build_query(<<~SELECTION)
          rollouts {
            nodes {
              id
              iid
              state
              application { id }
              versionSet { id }
              applicationFlowDefinition { id definition }
              rolloutTransitions { nodes { id event fromState toState } }
              rolloutEnvironments { nodes { id state position rollout { id } environment { id } } }
            }
          }
        SELECTION
      end

      before do
        restore_definition_file(application_flow_definition)
      end

      it 'resolves rollouts and their descendants' do
        post_query

        rollouts = application_response['rollouts']['nodes']
        expect(rollouts).to contain_exactly(a_graphql_entity_for(rollout))

        rollout_node = rollouts.first
        expect(rollout_node['iid']).to eq(rollout.iid)
        expect(rollout_node['application']).to match(a_graphql_entity_for(application))
        expect(rollout_node['versionSet']).to match(a_graphql_entity_for(version_set))
        expect(rollout_node['applicationFlowDefinition'])
          .to include(a_graphql_entity_for(application_flow_definition).to_hash)
        expect(rollout_node['applicationFlowDefinition']['definition']).to eq(application_flow_definition.definition)
        expect(rollout_node['rolloutTransitions']['nodes'])
          .to contain_exactly(a_graphql_entity_for(rollout_transition, :event))

        rollout_environment_node = rollout_node['rolloutEnvironments']['nodes'].first
        expect(rollout_environment_node).to include(a_graphql_entity_for(rollout_environment).to_hash)
        expect(rollout_environment_node['rollout']).to match(a_graphql_entity_for(rollout))
        expect(rollout_environment_node['environment']).to match(a_graphql_entity_for(environment))
      end
    end

    context 'with awaitingApproval and triggeredByUser across multiple rollouts' do
      let_it_be(:triggering_user) { create(:user) }
      let_it_be(:gated_rollout) do
        # Terminal state: only one non-terminal rollout is allowed per
        # application, and `rollout` (above) already holds that slot.
        create(:cd_rollout, version_set: version_set, application: application, state: :cancelled)
      end

      let_it_be(:gated_rollout_transition) do
        create(:cd_rollout_transition, rollout: gated_rollout, event: 'request_approval',
          principal: "user:#{triggering_user.id}")
      end

      let(:query) do
        build_query('rollouts { nodes { id awaitingApproval triggeredByUser { id } } }')
      end

      it 'resolves both fields correctly per rollout', :aggregate_failures do
        post_query

        rollouts_by_id = application_response['rollouts']['nodes'].index_by { |node| node['id'] }

        expect(rollouts_by_id[global_id_of(rollout).to_s]).to include(
          'awaitingApproval' => false,
          'triggeredByUser' => nil
        )
        expect(rollouts_by_id[global_id_of(gated_rollout).to_s]).to include(
          'awaitingApproval' => true,
          'triggeredByUser' => a_graphql_entity_for(triggering_user)
        )
      end

      it 'avoids N+1 queries as the number of rollouts grows' do
        run_query = -> do
          post_graphql(query, current_user: current_user, variables: { id: organization.to_global_id.to_s })
        end

        run_query.call # warm caches

        control = ActiveRecord::QueryRecorder.new { run_query.call }

        another_rollout = create(:cd_rollout, version_set: version_set, application: application, state: :cancelled)
        create(:cd_rollout_transition, rollout: another_rollout, event: 'request_approval',
          principal: "user:#{create(:user).id}")

        expect { run_query.call }.not_to exceed_query_limit(control)
      end
    end

    context 'with rollout search' do
      let_it_be(:other_rollout) do
        create(:cd_rollout, version_set: version_set, application: application, state: :cancelled)
      end

      let(:query) do
        build_query(<<~SELECTION)
          rollouts(search: "#{rollout.iid}") {
            nodes { id iid }
          }
        SELECTION
      end

      it 'returns only the rollout matching the searched IID' do
        post_query

        rollouts = application_response['rollouts']['nodes']
        expect(rollouts).to contain_exactly(a_graphql_entity_for(rollout, :iid))
      end

      it 'does not run an extra query per rollout (no N+1)' do
        unfiltered = build_query('rollouts { nodes { id iid } }')
        run = -> do
          post_graphql(unfiltered, current_user: current_user, variables: { id: organization.to_global_id.to_s })
        end

        run.call
        control = ActiveRecord::QueryRecorder.new { run.call }

        create(:cd_rollout, version_set: version_set, application: application, state: :cancelled)

        expect { run.call }.not_to exceed_query_limit(control)
      end
    end

    context 'with deployments' do
      let(:query) do
        build_query(<<~SELECTION)
          rollouts {
            nodes {
              rolloutEnvironments {
                nodes {
                  deployments {
                    nodes {
                      id
                      service { id }
                      rolloutEnvironment { id }
                    }
                  }
                }
              }
            }
          }
        SELECTION
      end

      it 'resolves deployments and their parent associations' do
        post_query

        rollout_environment_node =
          application_response['rollouts']['nodes'].first['rolloutEnvironments']['nodes'].first
        deployments = rollout_environment_node['deployments']['nodes']

        expect(deployments).to contain_exactly(a_graphql_entity_for(deployment))

        deployment_node = deployments.first
        expect(deployment_node['service']).to match(a_graphql_entity_for(service))
        expect(deployment_node['rolloutEnvironment']).to match(a_graphql_entity_for(rollout_environment))
      end
    end

    context 'with application links' do
      let(:query) do
        build_query('links { nodes { id name url linkType application { id } } }')
      end

      it 'resolves application links and their parent association' do
        post_query

        links = application_response['links']['nodes']
        expect(links).to contain_exactly(a_graphql_entity_for(application_link, :name, :url))

        link_node = links.first
        expect(link_node['linkType']).to eq(application_link.link_type.upcase)
        expect(link_node['application']).to match(a_graphql_entity_for(application))
      end
    end

    context 'with application flow definitions' do
      let_it_be(:later_flow_definition) do
        create(:cd_application_flow_definition, application: application)
      end

      let(:query) do
        build_query('applicationFlowDefinitions { nodes { id version definition application { id } } }')
      end

      before do
        restore_definition_file(application_flow_definition)
        restore_definition_file(later_flow_definition)
      end

      it 'resolves application flow definitions ordered by version descending' do
        post_query

        flow_definitions = application_response['applicationFlowDefinitions']['nodes']
        expect(flow_definitions.pluck('id')).to eq(
          [
            global_id_of(later_flow_definition).to_s,
            global_id_of(application_flow_definition).to_s
          ]
        )

        flow_definition_node = flow_definitions.first
        expect(flow_definition_node['definition']).to eq(later_flow_definition.definition)
        expect(flow_definition_node['application']).to match(a_graphql_entity_for(application))
      end
    end
  end

  context 'when traversing the nested connections across multiple applications' do
    let(:query) do
      build_query(<<~SELECTION)
        services { nodes { id } }
        versionSets { nodes { id } }
        rollouts { nodes { id applicationFlowDefinition { id } } }
        applicationFlowDefinitions { nodes { id } }
        links { nodes { id } }
      SELECTION
    end

    def create_application_with_nested_data
      app = create(:cd_application, organization: organization)
      svc = create(:cd_service, application: app)
      create(:cd_artifact_source, service: svc)
      vs = create(:cd_version_set, application: app)
      flow_definition = create(:cd_application_flow_definition, application: app)
      create(:cd_application_link, application: app)
      rollout = create(:cd_rollout, version_set: vs, application: app,
        application_flow_definition: flow_definition)
      create(:cd_rollout_transition, rollout: rollout)
    end

    it 'avoids N+1 queries as the number of applications grows' do
      run_query = -> do
        post_graphql(query, current_user: current_user, variables: { id: organization.to_global_id.to_s })
      end

      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      create_application_with_nested_data

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  context 'when traversing rollouts down to deployment transitions across multiple deployments' do
    let(:query) do
      build_query(<<~SELECTION)
        rollouts {
          nodes {
            rolloutEnvironments {
              nodes {
                deployments {
                  nodes {
                    id
                    deploymentTransitions { nodes { id } }
                  }
                }
              }
            }
          }
        }
      SELECTION
    end

    def create_deployment_with_transition
      another_service = create(:cd_service, application: application)
      deployment = create(:cd_deployment, service: another_service, rollout_environment: rollout_environment)
      create(:cd_deployment_transition, deployment: deployment)
    end

    it 'avoids N+1 queries as the number of deployments grows' do
      run_query = -> do
        post_graphql(query, current_user: current_user, variables: { id: organization.to_global_id.to_s })
      end

      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      create_deployment_with_transition

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }
    let(:query) { build_query('services { nodes { id } }') }

    it 'does not return the applications' do
      post_query

      expect(graphql_dig_at(graphql_data, :organization, :cd_applications, :nodes)).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    let(:query) { build_query('services { nodes { id } }') }

    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the applications' do
      post_query

      expect(graphql_dig_at(graphql_data, :organization, :cd_applications, :nodes)).to be_nil
    end
  end

  describe 'granular token authorization' do
    # Covers the CdApplicationFlowDefinition type.
    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_cd_application_flow_definition, :read_cd_application, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:query) { build_query('applicationFlowDefinitions { nodes { id version } }') }
      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s },
          token: { personal_access_token: pat }
        )
      end
    end

    # Covers the CdApplicationLink type.
    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_cd_application_link, :read_cd_application, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:query) { build_query('links { nodes { id name url linkType } }') }
      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s },
          token: { personal_access_token: pat }
        )
      end
    end

    # Covers the CdArtifactSource type.
    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_cd_artifact_source, :read_cd_service, :read_cd_application, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:query) do
        build_query('services { nodes { id artifactSources { nodes { id sourceRef } } } }')
      end

      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s },
          token: { personal_access_token: pat }
        )
      end
    end
  end
end
