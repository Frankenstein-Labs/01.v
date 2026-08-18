# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating an Artifact Registry repository', feature_category: :artifact_registry do
  include GraphqlHelpers

  let_it_be(:current_organization) { create(:organization) }
  let_it_be(:current_user) { create(:organization_user, organization: current_organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:created_repository) do
    ArtifactRegistry::Repository.new(
      'name' => 'my-repo',
      'format' => 'maven',
      'kind' => 'hosted',
      'visibility' => 'private',
      'description' => 'A repo',
      'downloads_count' => 0,
      'size_bytes' => 0,
      'settings' => {}
    )
  end

  let(:client) { instance_double(ArtifactRegistry::Client) }

  let(:input) do
    {
      'name' => 'my-repo',
      'format' => 'MAVEN',
      'visibility' => 'PRIVATE',
      'description' => 'A repo'
    }
  end

  let(:mutation) { graphql_mutation(:artifact_registry_repository_create, input) }

  def mutation_response
    graphql_mutation_response(:artifact_registry_repository_create)
  end

  context 'when the artifact_registry_ui flag is on' do
    before do
      # The organization is a let_it_be record that memoizes its client, so the
      # memo can carry a double from one example into the next. Clear it, then
      # stub Client.new to return this example's double.
      current_organization.clear_memoization(:artifact_registry_client)
      allow(ArtifactRegistry::Client).to receive(:new).and_return(client)
    end

    it 'creates the repository and returns it with no errors', :aggregate_failures do
      expect(client).to receive(:create_repository).with(
        slug: current_organization.artifact_registry_slug,
        name: 'my-repo',
        format: 'maven',
        kind: nil,
        visibility: 'private',
        description: 'A repo'
      ).and_return(created_repository)

      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
      expect(mutation_response['repository']).to include('name' => 'my-repo', 'description' => 'A repo')
    end

    context 'when Artifact Registry rejects the name (duplicate or invalid)' do
      it 'surfaces the error in the payload errors', :aggregate_failures do
        allow(client).to receive(:create_repository)
          .and_raise(ArtifactRegistry::Client::ApiError.new('name has already been taken', status: 409))

        post_graphql_mutation(mutation, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to include(a_string_matching(/already been taken/))
        expect(mutation_response['repository']).to be_nil
      end
    end

    context 'when Artifact Registry denies the create (403)' do
      it 'renders a top-level ResourceNotAvailable' do
        allow(client).to receive(:create_repository)
          .and_raise(ArtifactRegistry::Client::AuthorizationError.new('forbidden', status: 403))

        post_graphql_mutation(mutation, current_user: current_user)

        expect(graphql_errors).to include(a_hash_including('message' => /don't have permission/))
      end
    end

    context 'when an optional enum argument is explicitly null' do
      let(:input) { { 'name' => 'my-repo', 'format' => 'MAVEN', 'visibility' => nil } }

      it 'rejects the argument rather than dropping the null', :aggregate_failures do
        expect(client).not_to receive(:create_repository)

        post_graphql_mutation(mutation, current_user: current_user)

        expect(graphql_errors).to include(a_hash_including('message' => "visibility can't be null"))
      end
    end

    context 'when a non-hosted kind is requested' do
      let(:input) do
        { 'name' => 'my-repo', 'format' => 'MAVEN', 'kind' => 'REMOTE' }
      end

      it 'passes the kind through to Artifact Registry and surfaces its rejection', :aggregate_failures do
        expect(client).to receive(:create_repository)
          .with(hash_including(kind: 'remote'))
          .and_raise(ArtifactRegistry::Client::ApiError.new('kind not supported', status: 422))

        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['errors']).to include(a_string_matching(/not supported/))
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
