# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deleting an Artifact Registry repository', feature_category: :artifact_registry do
  include GraphqlHelpers

  let_it_be(:current_organization) { create(:organization) }
  let_it_be(:current_user) { create(:organization_user, organization: current_organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:client) { instance_double(ArtifactRegistry::Client) }

  let(:input) { { 'name' => 'my-repo' } }

  let(:mutation) { graphql_mutation(:artifact_registry_repository_delete, input) }

  def mutation_response
    graphql_mutation_response(:artifact_registry_repository_delete)
  end

  context 'when the artifact_registry_ui flag is on' do
    before do
      # The organization is a let_it_be record that memoizes its client, so the
      # memo can carry a double from one example into the next. Clear it, then
      # stub Client.new to return this example's double.
      current_organization.clear_memoization(:artifact_registry_client)
      allow(ArtifactRegistry::Client).to receive(:new).and_return(client)
    end

    it 'deletes the repository and returns no errors', :aggregate_failures do
      expect(client).to receive(:delete_repository).with(
        slug: current_organization.artifact_registry_slug,
        name: 'my-repo'
      ).and_return(true)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
    end

    context 'when Artifact Registry denies the delete (403)' do
      it 'renders a top-level ResourceNotAvailable' do
        allow(client).to receive(:delete_repository)
          .and_raise(ArtifactRegistry::Client::AuthorizationError.new('forbidden', status: 403))

        post_graphql_mutation(mutation, current_user: current_user)

        expect(graphql_errors).to include(a_hash_including('message' => /don't have permission/))
      end
    end
  end

  context 'when the user cannot read the organization registry' do
    it 'raises a top-level ResourceNotAvailable and makes no client call', :aggregate_failures do
      expect(ArtifactRegistry::Client).not_to receive(:new)

      post_graphql_mutation(mutation, current_user: non_member)

      expect(graphql_errors).to include(a_hash_including('message' => /don't have permission/))
    end
  end

  context 'when the artifact_registry_ui flag is off' do
    before do
      stub_feature_flags(artifact_registry_ui: false)
    end

    it 'raises a top-level ResourceNotAvailable and makes no client call', :aggregate_failures do
      expect(ArtifactRegistry::Client).not_to receive(:new)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => /don't have permission/))
    end
  end
end
