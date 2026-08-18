# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organization cd_version_set', feature_category: :continuous_delivery do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:other_organization) { create(:organization) }
  let_it_be(:application) { create(:cd_application, organization: organization) }
  let_it_be(:other_org_application) { create(:cd_application, organization: other_organization) }

  let_it_be(:version_set) { create(:cd_version_set, application: application) }
  let_it_be(:other_org_version_set) { create(:cd_version_set, application: other_org_application) }

  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: organization).user }
  let_it_be(:organization_member) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:current_user) { organization_owner }
  let(:version_set_gid) { version_set.to_global_id.to_s }

  let(:query) do
    <<~QUERY
      query organizationCdVersionSet(
        $id: OrganizationsOrganizationID!,
        $versionSetId: CdVersionSetID!
      ) {
        organization(id: $id) {
          cdVersionSet(id: $versionSetId) {
            id
            name
            application { id name }
            author { id }
            createdAt
            updatedAt
          }
        }
      }
    QUERY
  end

  subject(:post_query) do
    post_graphql(
      query,
      current_user: current_user,
      variables: { id: organization.to_global_id.to_s, versionSetId: version_set_gid }
    )
  end

  context 'when the user is an organization owner' do
    it 'returns the version set with its details', :aggregate_failures do
      post_query

      expect(version_set_response).to a_graphql_entity_for(version_set, :name)
      expect(version_set_response['application']).to a_graphql_entity_for(application, :name)
      expect(version_set_response['createdAt']).to be_present
      expect(version_set_response['updatedAt']).to be_present
    end

    context 'when the version set belongs to a different organization' do
      let(:version_set_gid) { other_org_version_set.to_global_id.to_s }

      it 'returns nil' do
        post_query

        expect(version_set_response).to be_nil
      end
    end

    context 'when the version set has an author' do
      let_it_be(:author) { create(:user) }
      let_it_be(:authored_version_set) { create(:cd_version_set, application: application, created_by: author) }

      let(:version_set_gid) { authored_version_set.to_global_id.to_s }

      it 'returns the author' do
        post_query

        expect(version_set_response['author']).to a_graphql_entity_for(author)
      end
    end

    context 'when the version set has no author' do
      it 'returns nil for author' do
        post_query

        expect(version_set_response['author']).to be_nil
      end
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL',
      [:read_cd_version_set, :read_cd_application, :read_organization] do
      let(:user) { organization_owner }
      let(:boundary_object) { :instance }
      let(:request) do
        post_graphql(
          query,
          variables: { id: organization.to_global_id.to_s, versionSetId: version_set.to_global_id.to_s },
          token: { personal_access_token: pat }
        )
      end
    end
  end

  context 'when the user is a non-owner organization member' do
    let(:current_user) { organization_member }

    it 'does not return the version set' do
      post_query

      expect(version_set_response).to be_nil
    end
  end

  context 'when the user is not a member of the organization' do
    let(:current_user) { non_member }

    it 'does not return the version set' do
      post_query

      expect(version_set_response).to be_nil
    end
  end

  context 'when the request is unauthenticated' do
    let(:current_user) { nil }

    it 'does not return the version set' do
      post_query

      expect(version_set_response).to be_nil
    end
  end

  context 'when the ai_native_deploy feature flag is disabled' do
    before do
      stub_feature_flags(ai_native_deploy: false)
    end

    it 'does not return the version set' do
      post_query

      expect(version_set_response).to be_nil
    end
  end

  def version_set_response
    graphql_dig_at(graphql_data, :organization, :cd_version_set)
  end
end
