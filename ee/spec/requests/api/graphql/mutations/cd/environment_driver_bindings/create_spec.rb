# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a continuous deployment environment driver binding', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:environment) { create(:cd_environment, organization: organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let(:current_user) { organization_owner }
  let(:input) do
    {
      environment_id: environment.to_global_id.to_s,
      environment_driver_binding: {
        driver_ref: 'argo-rollouts',
        driver_config: { cluster_agent_id: '1' }
      }
    }
  end

  let(:mutation) { build_driver_binding_mutation }
  let(:mutation_response) { graphql_mutation_response(:cd_environment_driver_binding_create) }

  # graphql_mutation camelizes every nested hash key when building variables, which is correct for
  # real GraphQL argument names but wrong for driver_config: it's an opaque JSON value whose keys are
  # the driver's own (snake_case) schema property names, never touched by GraphQL casing conventions.
  # Serializing variables to a JSON string up front (instead of the usual Hash) bypasses that camelization.
  def build_driver_binding_mutation(fields = nil)
    built = graphql_mutation(:cd_environment_driver_binding_create, input, fields)
    variable_name = built.variables.each_key.first
    built.variables[variable_name]['environmentDriverBinding']['driverConfig'] =
      input[:environment_driver_binding][:driver_config].stringify_keys
    built.variables = Gitlab::Json.dump(built.variables)
    built
  end

  shared_examples 'rejects the mutation' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a driver binding' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { ::Cd::EnvironmentDriverBinding.count }
    end
  end

  context 'when the user is an organization owner' do
    it 'creates the first driver binding on the environment', :aggregate_failures do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Cd::EnvironmentDriverBinding.count }.by(1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['environmentDriverBinding']).to include(
        'version' => 1,
        'driverRef' => 'argo-rollouts',
        'driverConfig' => { 'cluster_agent_id' => '1' }
      )
      expect(environment.environment_driver_bindings.sole).to have_attributes(
        version: 1,
        driver_ref: 'argo-rollouts'
      )
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_cd_environment do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { build_driver_binding_mutation('errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when a binding already exists for the environment' do
      before do
        create(:cd_environment_driver_binding, environment: environment)
      end

      it 'creates the next version instead of failing' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to change { ::Cd::EnvironmentDriverBinding.count }.by(1)

        expect(mutation_response['errors']).to be_empty
        expect(mutation_response['environmentDriverBinding']).to include('version' => 2)
      end
    end

    context 'when driver_ref is blank' do
      let(:input) do
        {
          environment_id: environment.to_global_id.to_s,
          environment_driver_binding: {
            driver_ref: '',
            driver_config: { cluster_agent_id: '1' }
          }
        }
      end

      it 'returns errors in the response' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::EnvironmentDriverBinding.count }

        expect(mutation_response['environmentDriverBinding']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/Driver ref can't be blank/))
      end
    end
  end

  context 'when the user is an organization member' do
    let(:current_user) { organization_member }

    it_behaves_like 'rejects the mutation'
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { create(:user) }

    it_behaves_like 'rejects the mutation'
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it_behaves_like 'rejects the mutation'
  end
end
