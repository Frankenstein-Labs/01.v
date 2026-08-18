# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cdRollout nested reads', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:service) { create(:cd_service, application: application) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }

  let_it_be(:environment) { create(:cd_environment, organization: organization) }
  let_it_be(:rollout) { create(:cd_rollout, version_set: version_set, application: application) }
  let_it_be(:rollout_transition) { create(:cd_rollout_transition, rollout: rollout) }
  let_it_be(:rollout_environment) do
    create(:cd_rollout_environment, rollout: rollout, environment: environment)
  end

  let_it_be(:deployment) do
    create(:cd_deployment, service: service, rollout_environment: rollout_environment)
  end

  let_it_be(:deployment_transition) { create(:cd_deployment_transition, deployment: deployment) }

  let_it_be(:rollout_step) do
    create(:cd_rollout_step, rollout: rollout, path: '0', step_type: 'com.gitlab.cd.steps.stage')
  end

  let_it_be(:nested_rollout_step) do
    create(:cd_rollout_step, rollout: rollout, rollout_environment: rollout_environment,
      path: '0.0', parent_path: '0')
  end

  let(:current_user) { organization_owner }
  let(:rollout_gid) { rollout.to_global_id.to_s }

  subject(:post_query) do
    post_graphql(
      query,
      current_user: current_user,
      variables: { id: organization.to_global_id.to_s, rolloutId: rollout_gid }
    )
  end

  def build_query(selection)
    <<~QUERY
      query organizationCdRollout(
        $id: OrganizationsOrganizationID!,
        $rolloutId: CdRolloutID!
      ) {
        organization(id: $id) {
          cdRollout(id: $rolloutId) {
            id
            #{selection}
          }
        }
      }
    QUERY
  end

  def rollout_response
    graphql_dig_at(graphql_data, :organization, :cd_rollout)
  end

  context 'when the user is an organization owner' do
    context 'with the parent application and version set' do
      let(:query) do
        build_query(<<~SELECTION)
          application { id name }
          versionSet { id name application { id } }
        SELECTION
      end

      it 'resolves the application and version set' do
        post_query

        expect(rollout_response['application']).to match(a_graphql_entity_for(application, :name))
        expect(rollout_response['versionSet']).to include(a_graphql_entity_for(version_set, :name).to_hash)
        expect(rollout_response['versionSet']['application']).to match(a_graphql_entity_for(application))
      end
    end

    context 'with rollout transitions' do
      let(:query) do
        build_query(<<~SELECTION)
          rolloutTransitions {
            nodes {
              id
              event
              fromState
              toState
            }
          }
        SELECTION
      end

      it 'resolves the rollout transitions' do
        post_query

        expect(rollout_response.dig('rolloutTransitions', 'nodes')).to contain_exactly(
          a_graphql_entity_for(rollout_transition, :event)
        )
      end

      context 'with a principal user' do
        let_it_be(:principal_user) { create(:user) }
        let_it_be(:principal_rollout_transition) do
          create(:cd_rollout_transition, rollout: rollout, event: 'promote', from_state: :in_progress,
            to_state: :completed, principal: "user:#{principal_user.id}")
        end

        let(:query) do
          build_query(<<~SELECTION)
            rolloutTransitions {
              nodes {
                id
                event
                principalUser {
                  id
                  username
                }
              }
            }
          SELECTION
        end

        it 'resolves the user of a principal that identifies a known user' do
          post_query

          expect(rollout_response.dig('rolloutTransitions', 'nodes')).to include(
            a_graphql_entity_for(principal_rollout_transition, :event,
              principal_user: a_hash_including('username' => principal_user.username))
          )
        end

        context 'when the principal does not identify a known user' do
          let_it_be(:unresolvable_rollout_transition) do
            create(:cd_rollout_transition, rollout: rollout, event: 'external-trigger', from_state: :in_progress,
              to_state: :paused, principal: 'service_account:1')
          end

          it 'returns a null principal user' do
            post_query

            expect(rollout_response.dig('rolloutTransitions', 'nodes')).to include(
              a_graphql_entity_for(unresolvable_rollout_transition, :event, principal_user: nil)
            )
          end
        end

        context 'when the principal identifies a user that no longer exists' do
          let_it_be(:deleted_user_rollout_transition) do
            create(:cd_rollout_transition, rollout: rollout, event: 'cleanup', from_state: :in_progress,
              to_state: :failed, principal: "user:#{non_existing_record_id}")
          end

          it 'returns a null principal user' do
            post_query

            expect(rollout_response.dig('rolloutTransitions', 'nodes')).to include(
              a_graphql_entity_for(deleted_user_rollout_transition, :event, principal_user: nil)
            )
          end
        end
      end
    end

    context 'with awaitingApproval' do
      let(:query) { build_query('awaitingApproval') }

      it 'is false when the rollout has no open approval gate' do
        post_query

        expect(rollout_response['awaitingApproval']).to be(false)
      end

      context 'when the rollout has an open approval gate' do
        let_it_be(:gate_transition) do
          create(:cd_rollout_transition, rollout: rollout, event: 'request_approval')
        end

        it 'is true' do
          post_query

          expect(rollout_response['awaitingApproval']).to be(true)
        end
      end
    end

    context 'with rollout environments and their back-references' do
      let(:query) do
        build_query(<<~SELECTION)
          rolloutEnvironments {
            nodes {
              id
              state
              position
              rollout { id }
              environment { id name }
            }
          }
        SELECTION
      end

      it 'resolves rollout environments and their associations' do
        post_query

        nodes = rollout_response.dig('rolloutEnvironments', 'nodes')
        expect(nodes).to contain_exactly(a_graphql_entity_for(rollout_environment, :position))

        node = nodes.first
        expect(node['rollout']).to match(a_graphql_entity_for(rollout))
        expect(node['environment']).to match(a_graphql_entity_for(environment, :name))
      end
    end

    context 'with rollout steps and their nested steps' do
      let(:query) do
        build_query(<<~SELECTION)
          rolloutSteps {
            id
            stepType
            steps {
              id
              stepType
              environment { id }
            }
          }
        SELECTION
      end

      it 'resolves the top-level steps and their nested children' do
        post_query

        nodes = rollout_response['rolloutSteps']
        expect(nodes).to contain_exactly(a_graphql_entity_for(rollout_step))

        nested_node = nodes.first['steps'].sole
        expect(nested_node).to match(a_graphql_entity_for(nested_rollout_step))
        expect(nested_node['environment']).to match(a_graphql_entity_for(environment))
      end
    end

    context 'with deployments under rollout environments' do
      let(:query) do
        build_query(<<~SELECTION)
          rolloutEnvironments {
            nodes {
              deployments {
                nodes {
                  id
                  state
                  service { id name }
                  rolloutEnvironment { id }
                }
              }
            }
          }
        SELECTION
      end

      it 'resolves deployments and their parent associations' do
        post_query

        rollout_environment_node = rollout_response.dig('rolloutEnvironments', 'nodes').first
        deployments = rollout_environment_node.dig('deployments', 'nodes')

        expect(deployments).to contain_exactly(a_graphql_entity_for(deployment))

        deployment_node = deployments.first
        expect(deployment_node['service']).to match(a_graphql_entity_for(service, :name))
        expect(deployment_node['rolloutEnvironment']).to match(a_graphql_entity_for(rollout_environment))
      end
    end

    context 'with deployment transitions (deepest traversal)' do
      let(:query) do
        build_query(<<~SELECTION)
          rolloutEnvironments {
            nodes {
              deployments {
                nodes {
                  id
                  deploymentTransitions {
                    nodes {
                      id
                      event
                      fromState
                      toState
                    }
                  }
                }
              }
            }
          }
        SELECTION
      end

      it 'resolves the deployment transition journal at the leaf' do
        post_query

        deployment_node =
          rollout_response.dig('rolloutEnvironments', 'nodes').first
            .dig('deployments', 'nodes').first

        expect(deployment_node.dig('deploymentTransitions', 'nodes')).to contain_exactly(
          a_graphql_entity_for(deployment_transition, :event)
        )
      end
    end
  end

  context 'when traversing rollout environments down to deployment transitions' do
    let(:query) do
      build_query(<<~SELECTION)
        awaitingApproval
        rolloutEnvironments {
          nodes {
            id
            environment { id }
            rollout { id }
            deployments {
              nodes {
                id
                service { id }
                rolloutEnvironment { id }
                deploymentTransitions { nodes { id } }
              }
            }
          }
        }
        rolloutTransitions { nodes { id principalUser { id username } } }
      SELECTION
    end

    def create_more_data_for_n_plus_one_test
      another_service = create(:cd_service, application: application)
      another_deployment = create(:cd_deployment,
        service: another_service,
        rollout_environment: rollout_environment)

      create(:cd_deployment_transition, deployment: another_deployment)
      create(:cd_deployment_transition, deployment: deployment)
      create(:cd_rollout_transition, rollout: rollout, principal: "user:#{create(:user).id}")
    end

    it 'avoids N+1 queries as the number of deployments and transitions grows' do
      run_query = -> do
        post_graphql(query, current_user: current_user,
          variables: { id: organization.to_global_id.to_s, rolloutId: rollout_gid })
      end

      run_query.call # warm caches

      control = ActiveRecord::QueryRecorder.new { run_query.call }

      create_more_data_for_n_plus_one_test

      expect { run_query.call }.not_to exceed_query_limit(control)
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }
    let(:query) { build_query('state') }

    it 'does not return the rollout' do
      post_query

      expect(rollout_response).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    let(:query) { build_query('state') }

    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the rollout' do
      post_query

      expect(rollout_response).to be_nil
    end
  end

  describe 'granular token authorization' do
    # Covers the CdRollout type.
    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_cd_rollout, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:query) { build_query('state workflowRef') }
      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s, rolloutId: rollout_gid },
          token: { personal_access_token: pat }
        )
      end
    end

    # Covers the CdRolloutEnvironment type.
    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_cd_rollout, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:query) { build_query('rolloutEnvironments { nodes { id state position } }') }
      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s, rolloutId: rollout_gid },
          token: { personal_access_token: pat }
        )
      end
    end

    # Covers the CdRolloutStep type.
    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_cd_rollout, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:query) { build_query('rolloutSteps { id stepType steps { id stepType } }') }
      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s, rolloutId: rollout_gid },
          token: { personal_access_token: pat }
        )
      end
    end

    # Covers the CdDeployment type.
    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_cd_rollout, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:query) do
        build_query('rolloutEnvironments { nodes { deployments { nodes { id state } } } }')
      end

      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s, rolloutId: rollout_gid },
          token: { personal_access_token: pat }
        )
      end
    end

    # Covers the CdDeploymentTransition type.
    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_cd_rollout, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:query) do
        build_query(<<~SELECTION)
          rolloutEnvironments {
            nodes {
              deployments {
                nodes {
                  deploymentTransitions { nodes { id event fromState toState } }
                }
              }
            }
          }
        SELECTION
      end

      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s, rolloutId: rollout_gid },
          token: { personal_access_token: pat }
        )
      end
    end
  end
end
