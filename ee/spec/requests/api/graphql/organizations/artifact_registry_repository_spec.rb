# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Reading a single Artifact Registry repository', feature_category: :artifact_registry do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:base_url) { 'https://artifact-registry.example.test' }
  let(:token) { 'ar-request-spec-credential' }
  let(:slug) { Organizations::ArtifactRegistry::STUB_SLUG }
  let(:repository_name) { 'my-repo' }
  let(:repository_url) { "#{base_url}/api/v1/#{slug}/repositories/#{repository_name}" }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  let(:repository_body) do
    {
      'id' => 'a1b2c3d4-0000-0000-0000-000000000000',
      'name' => repository_name,
      'format' => 'maven',
      'kind' => 'hosted',
      'visibility' => 'private',
      'description' => 'A hosted Maven repository',
      'downloads_count' => 340,
      'size_bytes' => 9_876_543_210,
      'last_updated_at' => '2026-07-02T11:30:00Z',
      'settings' => {}
    }
  end

  let(:query) do
    graphql_query_for(
      :organization,
      { id: organization.to_global_id.to_s },
      query_graphql_field(
        :artifact_registry_repository,
        { name: repository_name },
        'name format kind visibility description settings downloadsCount sizeBytes lastUpdatedAt'
      )
    )
  end

  let(:repository_data) { graphql_data.dig('organization', 'artifactRegistryRepository') }

  before do
    stub_config(artifact_registry: { api_url: base_url })

    allow_next_instance_of(ArtifactRegistry::TokenExchange) do |token_exchange|
      allow(token_exchange).to receive(:token_for).and_return(token)
    end
  end

  context 'when the artifact_registry_ui flag is on' do
    it 'reads the repository over HTTP and returns its fields', :aggregate_failures do
      request = stub_request(:get, repository_url)
        .to_return(status: 200, headers: json_headers, body: repository_body.to_json)

      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(request).to have_been_requested
      expect(repository_data).to include(
        'name' => repository_name,
        'format' => 'MAVEN',
        'kind' => 'HOSTED',
        'visibility' => 'PRIVATE',
        'description' => 'A hosted Maven repository',
        'settings' => {},
        'downloadsCount' => '340',
        'sizeBytes' => '9876543210'
      )
    end

    context 'when the repository is not found (AR returns 404)' do
      it 'resolves to null rather than erroring', :aggregate_failures do
        stub_request(:get, repository_url)
          .to_return(status: 404, headers: json_headers, body: { code: 'not_found' }.to_json)

        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(repository_data).to be_nil
        expect(graphql_errors).to be_nil
      end
    end

    context 'when AR is unavailable (5xx)' do
      it 'surfaces a top-level error' do
        stub_request(:get, repository_url)
          .to_return(status: 503, headers: json_headers, body: {}.to_json)

        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to be_present
      end
    end

    context 'when AR denies the read (401)' do
      it 'resolves to null rather than erroring', :aggregate_failures do
        # Artifact Registry hides existence: a denial reads as not-found, so the field
        # resolves null with no top-level error. The mutation slices rely on this.
        stub_request(:get, repository_url)
          .to_return(status: 401, headers: json_headers, body: {}.to_json)

        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(repository_data).to be_nil
        expect(graphql_errors).to be_nil
      end
    end

    context 'when the current user cannot read the organization' do
      it 'resolves to null and makes no HTTP call', :aggregate_failures do
        # The field is authorized read_artifact_registry against the organization, so a
        # user with no access to it never reaches Artifact Registry.
        request = stub_request(:get, repository_url)

        post_graphql(query, current_user: non_member)

        expect(response).to have_gitlab_http_status(:ok)
        expect(repository_data).to be_nil
        expect(request).not_to have_been_requested
      end
    end
  end

  context 'when the artifact_registry_ui flag is off' do
    it 'resolves to null and makes no HTTP call', :aggregate_failures do
      request = stub_request(:get, repository_url)

      stub_feature_flags(artifact_registry_ui: false)

      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(repository_data).to be_nil
      expect(request).not_to have_been_requested
    end
  end
end
