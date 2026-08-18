# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cd_available_deploy_drivers', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:current_user) { organization_owner }

  let(:query) do
    <<~QUERY
      query organizationCdAvailableDeployDrivers($id: OrganizationsOrganizationID!) {
        organization(id: $id) {
          id
          cdAvailableDeployDrivers
        }
      }
    QUERY
  end

  subject(:post_query) do
    post_graphql(query, current_user: current_user, variables: { id: organization.to_global_id.to_s })
  end

  context 'when the user is an organization owner' do
    it 'returns the registered driver refs' do
      post_query

      expect(deploy_drivers_response).to contain_exactly('argo-rollouts')
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }

    it 'does not return the drivers' do
      post_query

      expect(deploy_drivers_response).to be_nil
    end
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { non_member }

    it 'does not return the drivers' do
      post_query

      expect(deploy_drivers_response).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the drivers' do
      post_query

      expect(deploy_drivers_response).to be_nil
    end
  end

  def deploy_drivers_response
    graphql_dig_at(graphql_data, :organization, :cd_available_deploy_drivers)
  end
end
