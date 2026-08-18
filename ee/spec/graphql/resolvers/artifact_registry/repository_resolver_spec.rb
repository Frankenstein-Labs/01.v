# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ArtifactRegistry::RepositoryResolver, feature_category: :artifact_registry do
  # Per the GraphQL styleguide, resolver unit tests statically verify the schema only.
  # The flag-off, read-404, and denial behaviors are covered end to end by
  # ee/spec/requests/api/graphql/organizations/artifact_registry_repository_spec.rb.
  it 'resolves the repository type, nullable' do
    expect(described_class.type).to eq(::Types::ArtifactRegistry::RepositoryType)
    expect(described_class.type.non_null?).to be(false)
  end

  it 'requires a name argument' do
    argument = described_class.arguments['name']

    expect(argument.type.to_type_signature).to eq('String!')
  end
end
