# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::GoogleCloud::ArtifactRegistry::GetRepositoryService, feature_category: :container_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for an artifact registry service'

  describe '#execute' do
    subject(:execute) { service.execute }

    it_behaves_like 'an artifact registry service handling validation errors', client_method: :repository

    context 'with saas only feature enabled' do
      before do
        stub_saas_features(google_cloud_support: true)

        allow(client_double).to receive(:repository)
          .and_return(dummy_repository_response)
      end

      it 'returns the repository' do
        expect(execute).to be_success
        expect(execute.payload).to be_a ::Google::Cloud::ArtifactRegistry::V1::Repository
        expect(execute.payload.name).to eq('test')
      end
    end

    private

    def dummy_repository_response
      ::Google::Cloud::ArtifactRegistry::V1::Repository.new(name: 'test')
    end
  end
end
