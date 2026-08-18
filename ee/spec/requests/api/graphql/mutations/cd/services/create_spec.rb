# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a continuous deployment service', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let(:current_user) { organization_owner }
  let(:input) do
    {
      application_id: application.to_global_id.to_s,
      name: 'web',
      description: 'My service'
    }
  end

  let(:mutation) { graphql_mutation(:cd_service_create, input) }
  let(:mutation_response) { graphql_mutation_response(:cd_service_create) }

  context 'when the user is an organization owner' do
    it 'creates the service on the application' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Cd::Service.count }.by(1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['service']).to include(
        'name' => 'web',
        'description' => 'My service'
      )
      expect(::Cd::Service.last).to have_attributes(application: application, name: 'web')
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_cd_service do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:cd_service_create, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the name is already taken' do
      before do
        create(:cd_service, application: application, name: 'web')
      end

      it 'returns errors in the response' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::Service.count }

        expect(mutation_response['service']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/Name has already been taken/))
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

    it 'does not create the service' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { ::Cd::Service.count }
    end
  end
end
