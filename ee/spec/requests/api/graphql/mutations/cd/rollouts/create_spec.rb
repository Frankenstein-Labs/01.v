# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a continuous deployment rollout', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:environment) { create(:cd_environment, organization: organization, name: 'production') }
  let_it_be(:driver_binding) { create(:cd_environment_driver_binding, environment: environment) }

  let!(:flow_definition) do
    create(:cd_application_flow_definition, application: application, definition: <<~YAML)
      environments:
        production:
          services:
            web:
              namespace: argocd
              application: web-production
              manifest_repository:
                type: gitlab
                host: https://gitlab.example.com
                project: group/gitops
                branch: main
                manifests_path: manifests
      steps:
        - type: com.gitlab.cd.steps.stage
          name: canary
          steps:
            - type: com.gitlab.cd.argo.rolling.deploy
              environment: "production"
              services:
                - name: web
    YAML
  end

  let(:current_user) { organization_owner }
  let(:input) do
    {
      organization_id: organization.to_global_id.to_s,
      version_set_id: version_set.to_global_id.to_s
    }
  end

  let(:mutation) { graphql_mutation(:cd_rollout_create, input) }
  let(:mutation_response) { graphql_mutation_response(:cd_rollout_create) }

  before do
    allow(::Cd::Rollouts::StartWorker).to receive(:perform_async)
  end

  context 'when the user is an organization owner' do
    it 'creates the rollout' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Cd::Rollout.count }.by(1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['rollout']).to include('state' => 'PENDING')

      rollout = ::Cd::Rollout.last
      expect(rollout).to have_attributes(
        organization: organization,
        application: application,
        version_set: version_set,
        application_flow_definition: flow_definition
      )
    end

    it 'enqueues the kickoff worker' do
      expect(::Cd::Rollouts::StartWorker).to receive(:perform_async).with(kind_of(Integer))

      post_graphql_mutation(mutation, current_user: current_user)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_cd_rollout do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:cd_rollout_create, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  context 'when the user is an organization member' do
    let(:current_user) { organization_member }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { create(:user) }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create the rollout' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { ::Cd::Rollout.count }
    end
  end
end
