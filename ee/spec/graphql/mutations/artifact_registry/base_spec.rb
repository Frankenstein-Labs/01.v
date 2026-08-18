# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ArtifactRegistry::Base, feature_category: :artifact_registry do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:organization_user, organization: organization).user }
  let_it_be(:non_member) { create(:user) }

  let(:client) { instance_double(ArtifactRegistry::Client) }

  # A concrete mutation exercising the Base template: it returns a payload field
  # from #resolve_artifact_registry, which Base wraps with the standard errors.
  let(:mutation_class) do
    Class.new(described_class) do
      graphql_name 'TestArtifactRegistryMutation'

      field :value, GraphQL::Types::String, null: true, description: 'Test value.'

      def resolve_artifact_registry(**)
        { value: artifact_registry_client.repository(slug: 'acme', name: 'my-repo') }
      end
    end
  end

  let(:user) { current_user }
  let(:context) { query_context(user: user, organization: organization) }
  let(:mutation) { mutation_class.new(object: nil, context: context, field: nil) }

  before do
    allow(organization).to receive(:artifact_registry_client).with(current_user: current_user).and_return(client)
  end

  subject(:resolve) { mutation.resolve }

  context 'when the artifact_registry_ui flag is on and the user can read the registry' do
    it 'runs the concrete mutation and returns its payload with an empty errors array', :aggregate_failures do
      allow(client).to receive(:repository).and_return('a-repository')

      expect(resolve).to eq(value: 'a-repository', errors: [])
    end

    it 'maps a client API error into the payload errors', :aggregate_failures do
      allow(client).to receive(:repository)
        .and_raise(ArtifactRegistry::Client::ApiError.new('boom', status: 409))

      result = resolve

      expect(result[:errors]).to include('boom')
      expect(result[:value]).to be_nil
    end
  end

  context 'when the artifact_registry_ui flag is off' do
    before do
      stub_feature_flags(artifact_registry_ui: false)
    end

    it 'raises a top-level ResourceNotAvailable and acquires no client', :aggregate_failures do
      expect(organization).not_to receive(:artifact_registry_client)

      expect { resolve }.to raise_error(::Gitlab::Graphql::Errors::ResourceNotAvailable)
    end
  end

  context 'when the user cannot read the organization registry' do
    let(:user) { non_member }

    it 'raises a top-level ResourceNotAvailable and acquires no client', :aggregate_failures do
      expect(organization).not_to receive(:artifact_registry_client)

      expect { resolve }.to raise_error(::Gitlab::Graphql::Errors::ResourceNotAvailable)
    end
  end
end
