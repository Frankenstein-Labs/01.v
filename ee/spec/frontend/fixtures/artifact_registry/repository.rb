# frozen_string_literal: true

require 'spec_helper'

# The single-repository read, posted against the schema with Artifact Registry stubbed at the
# HTTP boundary. `repositories/detail/repository_detail_spec.js` imports the JSON this writes, so
# the detail spec renders the schema's own answer rather than a hand-written one. It is also the
# only place this document meets the schema: `Gitlab::Graphql::Queries.all`, which `graphql-verify`
# walks, covers `app/assets/javascripts` and not the `ee/` mirror the document lives under.
RSpec.describe 'Artifact Registry repository (JavaScript fixtures)',
  feature_category: :artifact_registry do
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  graphql_path = 'packages_and_registries/artifact_registry/graphql'

  # Refind, not reload: the organization memoizes its client, so a second example would inherit
  # this one's stubbed TokenExchange and fail as a missing credential.
  let_it_be_with_refind(:organization) { create(:organization) }
  let_it_be(:user) { create(:organization_user, organization: organization).user }

  let(:base_url) { 'https://artifact-registry.example.test' }
  let(:slug) { ::Organizations::ArtifactRegistry::STUB_SLUG }
  let(:name) { 'my-repository' }
  let(:repository_url) { "#{base_url}/api/v1/#{slug}/repositories/#{name}" }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  # A repository whose content has changed, so every counter and timestamp the detail read selects
  # carries a value rather than a null.
  let(:repository_body) do
    {
      'id' => 'a1b2c3d4-0000-0000-0000-000000000000',
      'name' => name,
      'format' => 'maven',
      'kind' => 'hosted',
      'visibility' => 'private',
      'description' => 'A hosted Maven repository',
      'artifacts_count' => 3,
      'downloads_count' => 1234,
      'size_bytes' => 2048,
      'created_at' => '2026-05-12T09:24:00Z',
      'last_updated_at' => '2026-06-01T00:00:00Z',
      'settings' => {}
    }
  end

  before do
    stub_config(artifact_registry: { api_url: base_url })

    allow_next_instance_of(::ArtifactRegistry::TokenExchange) do |token_exchange|
      allow(token_exchange).to receive(:token_for).and_return('ar-fixture-credential')
    end
  end

  describe GraphQL::Query, 'the detail read', type: :request do
    query_path = "#{graphql_path}/queries/get_repository_detail.query.graphql"

    let(:query) { get_graphql_query_as_string(query_path, ee: true) }
    let(:variables) { { organizationId: organization.to_global_id.to_s, name: name } }

    before do
      stub_request(:get, repository_url)
        .to_return(status: 200, headers: json_headers, body: repository_body.to_json)
    end

    it "ee/graphql/#{query_path}.json" do
      post_graphql(query, current_user: user, variables: variables)

      expect_graphql_errors_to_be_empty

      expect(graphql_data_at(:organization, :artifact_registry_repository)).to eq(
        '__typename' => 'ArtifactRegistryRepository',
        'name' => name,
        'format' => 'MAVEN',
        'kind' => 'HOSTED',
        'visibility' => 'PRIVATE',
        'description' => 'A hosted Maven repository',
        'downloadsCount' => '1234',
        'sizeBytes' => '2048',
        'lastUpdatedAt' => '2026-06-01T00:00:00+00:00'
      )
    end
  end
end
