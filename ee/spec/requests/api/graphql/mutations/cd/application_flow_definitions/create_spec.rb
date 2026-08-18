# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a continuous deployment application flow definition', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let(:current_user) { organization_owner }
  let(:definition) { "steps:\n  - type: com.gitlab.cd.steps.wait\n    seconds: 0\n" }
  let(:input) do
    {
      application_id: application.to_global_id.to_s,
      definition: definition
    }
  end

  let(:mutation) { graphql_mutation(:cd_application_flow_definition_create, input) }
  let(:mutation_response) { graphql_mutation_response(:cd_application_flow_definition_create) }

  context 'when the user is an organization owner' do
    it 'creates the flow definition on the application', :aggregate_failures do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Cd::ApplicationFlowDefinition.count }.by(1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['applicationFlowDefinition']).to include('version' => 1)

      flow_definition = ::Cd::ApplicationFlowDefinition.order(:id).last
      expect(flow_definition).to have_attributes(application: application, version: 1)
      expect(flow_definition.definition).to eq(definition)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_cd_application_flow_definition do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:cd_application_flow_definition_create, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when definition is blank' do
      let(:definition) { '' }

      it 'returns errors in the response' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::ApplicationFlowDefinition.count }

        expect(mutation_response['applicationFlowDefinition']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/Definition can't be blank/))
      end
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

    it 'does not create the flow definition' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { ::Cd::ApplicationFlowDefinition.count }
    end
  end
end
