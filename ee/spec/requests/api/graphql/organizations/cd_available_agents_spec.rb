# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cd_available_agents', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, organization: organization) }
  let_it_be(:agent) { create(:cluster_agent, project: project, name: 'demo-agent') }
  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:current_user) { organization_owner }

  let(:query) do
    <<~QUERY
      query organizationCdAvailableAgents($id: OrganizationsOrganizationID!) {
        organization(id: $id) {
          id
          cdAvailableAgents {
            nodes { id name }
          }
        }
      }
    QUERY
  end

  subject(:post_query) do
    post_graphql(query, current_user: current_user, variables: { id: organization.to_global_id.to_s })
  end

  context 'when the user is an organization owner' do
    it 'returns agents belonging to projects in the organization' do
      post_query

      expect(agents_response).to contain_exactly(a_graphql_entity_for(agent, :name))
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', [:read_cd_environment, :read_organization] do
      let_it_be(:granular_organization) { create(:organization) }

      let(:user) { create(:organization_user, :owner, organization: granular_organization).user }
      let(:boundary_object) { :instance }
      let(:query) do
        <<~QUERY
          query organizationCdAvailableAgents($id: OrganizationsOrganizationID!) {
            organization(id: $id) {
              cdAvailableAgents {
                nodes { id name }
              }
            }
          }
        QUERY
      end

      let(:request) do
        post_graphql(query, variables: { id: granular_organization.to_global_id.to_s },
          token: { personal_access_token: pat })
      end
    end

    context 'when the agent belongs to a project in a different organization' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_agent) { create(:cluster_agent, project: other_project) }

      it 'does not return the other organization agent' do
        post_query

        expect(agents_response).to contain_exactly(a_graphql_entity_for(agent, :name))
      end
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }

    it 'does not return the agents' do
      post_query

      expect(agents_response).to be_nil
    end
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { non_member }

    it 'does not return the agents' do
      post_query

      expect(agents_response).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the agents' do
      post_query

      expect(agents_response).to be_nil
    end
  end

  def agents_response
    graphql_dig_at(graphql_data, :organization, :cd_available_agents, :nodes)
  end
end
