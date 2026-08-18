# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ArtifactRegistry::BaseResolver, feature_category: :artifact_registry do
  let(:user) { build_stubbed(:user) }

  let(:client) { instance_double(ArtifactRegistry::Client) }

  let(:resource_class) do
    Class.new do
      include ArtifactRegistry::CachesClient

      def flipper_id
        'TestResource:1'
      end
    end
  end

  let(:resource) { resource_class.new }

  let(:resolver_class) do
    Class.new(described_class) do
      def resolve_artifact_registry(**_args)
        artifact_registry_client
      end
    end
  end

  let(:ctx) do
    GraphQL::Query::Context.new(
      query: GraphQL::Query.new(GitlabSchema, document: nil, context: {}, variables: {}),
      values: { current_user: user }
    )
  end

  let(:resolver) { resolver_class.new(object: resource, context: ctx, field: nil) }

  before do
    allow(resource).to receive(:artifact_registry_client).with(current_user: user).and_return(client)
  end

  context 'when the artifact_registry_ui flag is off' do
    before do
      stub_feature_flags(artifact_registry_ui: false)
    end

    it 'resolves to nil and makes no client call', :aggregate_failures do
      expect(resource).not_to receive(:artifact_registry_client)

      expect(resolver.resolve).to be_nil
    end
  end

  context 'when the artifact_registry_ui flag is on' do
    it 'acquires the client from the loaded resource, bound to current_user' do
      expect(resolver.resolve).to be(client)
    end

    it 'raises NotImplementedError when the concrete resolver body is missing' do
      bare = described_class.new(object: resource, context: ctx, field: nil)

      expect { bare.resolve }.to raise_error(NotImplementedError)
    end

    it 'renders a client error through the error concern rather than letting it escape' do
      raising_class = Class.new(described_class) do
        def resolve_artifact_registry(**_args)
          raise ::ArtifactRegistry::Client::AuthorizationError.new('forbidden', status: 403)
        end
      end

      raising = raising_class.new(object: resource, context: ctx, field: nil)

      expect(raising.resolve).to be_nil
    end
  end
end
