# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a continuous deployment environment', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be_with_reload(:environment) do
    create(:cd_environment, organization: organization, name: 'old-name', description: 'old description')
  end

  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }

  let(:current_user) { organization_owner }
  let(:input) do
    {
      id: environment.to_global_id.to_s,
      name: 'new-name',
      description: 'new description',
      tier: 'STAGING'
    }
  end

  let(:mutation) { graphql_mutation(:cd_environment_update, input) }
  let(:mutation_response) { graphql_mutation_response(:cd_environment_update) }

  context 'when the user is an organization owner' do
    it 'updates the environment', :aggregate_failures do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['environment']).to include(
        'name' => 'new-name',
        'description' => 'new description',
        'tier' => 'STAGING'
      )
      expect(environment.reload).to have_attributes(
        name: 'new-name',
        description: 'new description',
        tier: 'staging'
      )
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_cd_environment do
      let(:user) { current_user }
      let(:boundary_object) { :instance }
      let(:mutation) { graphql_mutation(:cd_environment_update, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    context 'when the name is already taken' do
      before do
        create(:cd_environment, organization: organization, name: 'new-name')
      end

      it 'returns errors and does not update the environment' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to include(a_string_matching(/Name has already been taken/))
        expect(environment.reload.name).to eq('old-name')
      end
    end

    context 'when tier is omitted from the input' do
      let(:input) do
        {
          id: environment.to_global_id.to_s,
          name: 'new-name'
        }
      end

      it 'preserves the existing tier', :aggregate_failures do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to be_empty
        expect(environment.reload.tier).to eq('development')
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

    it 'does not update the environment' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(environment.reload.name).to eq('old-name')
    end
  end
end
