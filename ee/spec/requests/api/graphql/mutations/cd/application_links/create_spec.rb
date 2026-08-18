# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a continuous deployment application link', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let(:current_user) { organization_owner }
  let(:input) do
    {
      application_id: application.to_global_id.to_s,
      name: 'Payments runbook',
      url: 'https://runbooks.example.com/payments',
      link_type: 'RUNBOOK'
    }
  end

  let(:mutation) { graphql_mutation(:cd_application_link_create, input) }
  let(:mutation_response) { graphql_mutation_response(:cd_application_link_create) }

  context 'when the user is an organization owner' do
    it 'creates the link on the application' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to change { ::Cd::ApplicationLink.count }.by(1)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['applicationLink']).to include(
        'name' => 'Payments runbook',
        'url' => 'https://runbooks.example.com/payments',
        'linkType' => 'RUNBOOK'
      )
      expect(::Cd::ApplicationLink.order(:id).last).to have_attributes(
        application: application,
        name: 'Payments runbook',
        link_type: 'runbook'
      )
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_cd_application_link do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:cd_application_link_create, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the URL is already taken' do
      before do
        create(:cd_application_link, application: application, url: 'https://runbooks.example.com/payments')
      end

      it 'returns errors in the response' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::ApplicationLink.count }

        expect(mutation_response['applicationLink']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/Url has already been taken/))
      end
    end

    context 'when the URL scheme is not allowed' do
      let(:input) { super().merge(url: 'javascript:alert(1)') }

      it 'returns errors in the response' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { ::Cd::ApplicationLink.count }

        expect(mutation_response['applicationLink']).to be_nil
        expect(mutation_response['errors']).to include(a_string_matching(/Url is blocked/))
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

    it 'does not create the link' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .not_to change { ::Cd::ApplicationLink.count }
    end
  end
end
