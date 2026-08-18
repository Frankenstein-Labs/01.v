# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a continuous deployment application link', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let_it_be_with_reload(:application_link) do
    create(:cd_application_link, application: application,
      name: 'Old runbook', url: 'https://old.example.com', link_type: :runbook)
  end

  let(:current_user) { organization_owner }
  let(:input) do
    {
      id: application_link.to_global_id.to_s,
      name: 'Payments dashboard',
      url: 'https://dash.example.com',
      link_type: 'DASHBOARD'
    }
  end

  let(:mutation) { graphql_mutation(:cd_application_link_update, input) }
  let(:mutation_response) { graphql_mutation_response(:cd_application_link_update) }

  context 'when the user is an organization owner' do
    it 'updates the link' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['applicationLink']).to include(
        'name' => 'Payments dashboard',
        'url' => 'https://dash.example.com',
        'linkType' => 'DASHBOARD'
      )
      expect(application_link.reload).to have_attributes(name: 'Payments dashboard', link_type: 'dashboard')
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_cd_application_link do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:cd_application_link_update, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the URL scheme is not allowed' do
      let(:input) { super().merge(url: 'javascript:alert(1)') }

      it 'returns errors and does not update the link', :aggregate_failures do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to include(a_string_matching(/Url is blocked/))
        expect(mutation_response['applicationLink']).to be_nil
        expect(application_link.reload.url).to eq('https://old.example.com')
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
  end
end
