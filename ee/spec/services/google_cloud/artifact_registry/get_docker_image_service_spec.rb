# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GoogleCloud::ArtifactRegistry::GetDockerImageService, feature_category: :container_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for an artifact registry service'

  describe '#execute' do
    let(:name) { 'test' }
    let(:params) { { name: name } }

    subject(:execute) { service.execute }

    it_behaves_like 'an artifact registry service handling validation errors', client_method: :docker_image

    context 'with saas only feature enabled' do
      before do
        stub_saas_features(google_cloud_support: true)

        allow(client_double).to receive(:docker_image).with(name: name).and_return(dummy_docker_image_response)
      end

      it 'returns the repository' do
        expect(execute).to be_success
        expect(execute.payload).to be_a ::Google::Cloud::ArtifactRegistry::V1::DockerImage
        expect(execute.payload.name).to eq(name)
      end

      context 'with a blank name' do
        let(:name) { '' }

        it_behaves_like 'returning an error service response',
          message: described_class::NO_NAME_ERROR_RESPONSE.message
      end
    end

    private

    def dummy_docker_image_response
      ::Google::Cloud::ArtifactRegistry::V1::DockerImage.new(name: name)
    end
  end
end
