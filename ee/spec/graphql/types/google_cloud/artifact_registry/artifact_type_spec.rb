# frozen_string_literal: true

require 'spec_helper'
require 'google/cloud/artifact_registry/v1'

RSpec.describe GitlabSchema.types['GoogleCloudArtifactRegistryArtifact'], feature_category: :container_registry do
  describe '.resolve_type' do
    let(:object) { Google::Cloud::ArtifactRegistry::V1::DockerImage.new(name: 'alpine') }

    subject(:mapping) { described_class.resolve_type(object, {}) }

    it { is_expected.to eq(::Types::GoogleCloud::ArtifactRegistry::DockerImageType) }

    context 'with an unknown type' do
      let(:object) { {} }

      it 'raises the error' do
        expect do
          mapping
        end.to raise_error(Gitlab::Graphql::Errors::BaseError, 'Unsupported Google Artifact Registry type Hash')
      end
    end
  end
end
