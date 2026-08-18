# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete a continuous deployment application link', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let!(:application_link) { create(:cd_application_link, application: application) }

  let(:current_user) { organization_owner }
  let(:input) { { id: application_link.to_global_id.to_s } }

  let(:mutation) { graphql_mutation(:cd_application_link_delete, input, 'errors') }
  let(:mutation_response) { graphql_mutation_response(:cd_application_link_delete) }

  context 'when the user is an organization owner' do
    it 'deletes the link' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Cd::ApplicationLink.count }.by(-1)

      expect(mutation_response['errors']).to be_empty
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_cd_application_link do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end

  context 'when the user is an organization member' do
    let(:current_user) { organization_member }

    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not delete the link' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { ::Cd::ApplicationLink.count }
    end
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
  end
end
