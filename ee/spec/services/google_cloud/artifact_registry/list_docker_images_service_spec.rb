# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GoogleCloud::ArtifactRegistry::ListDockerImagesService, feature_category: :container_registry do
  using RSpec::Parameterized::TableSyntax
  include_context 'for an artifact registry service'

  describe '#execute' do
    let(:page_token) { 'token' }
    let(:order_by) { 'name asc' }
    let(:page_size) { 20 }
    let(:params) { { page_token: page_token, order_by: order_by, page_size: page_size } }

    subject(:execute) { service.execute }

    it_behaves_like 'an artifact registry service handling validation errors', client_method: :docker_images

    context 'with saas only feature enabled' do
      before do
        stub_saas_features(google_cloud_support: true)

        allow(client_double).to receive(:docker_images)
          .with(page_size: page_size, page_token: page_token, order_by: order_by)
          .and_return(dummy_list_response)
      end

      it 'returns the docker images' do
        expect(execute).to be_success
        expect(execute.payload).to be_a Google::Cloud::ArtifactRegistry::V1::ListDockerImagesResponse
        expect(execute.payload.docker_images).to be_a Enumerable
        expect(execute.payload.next_page_token).to eq('next_page_token')
      end

      context 'with an invalid page_size' do
        let(:page_size) { 'test' }

        it_behaves_like 'returning an error service response',
          message: described_class::INVALID_PAGE_SIZE_ERROR_RESPONSE.message
      end

      context 'with a too large page_size' do
        let(:page_size) { described_class::MAX_PAGE_SIZE }

        let(:params) { super().merge(page_size: described_class::MAX_PAGE_SIZE + 100) }

        it 'sets page_size to MAX_PAGE_SIZE' do
          expect(execute).to be_success
        end
      end

      context 'with a nil page_size' do
        let(:page_size) { described_class::DEFAULT_PAGE_SIZE }

        let(:params) { super().merge(page_size: nil) }

        it 'sets page_size to DEFAULT_PAGE_SIZE' do
          expect(execute).to be_success
        end
      end

      context 'with a nil order_by' do
        let(:order_by) { nil }

        it 'does not set order_by' do
          expect(execute).to be_success
        end
      end

      context 'with an invalid order_by' do
        where(:field, :direction) do
          'test' | 'asc'
          'name' | 'greater_than'
          ''     | 'desc'
          'name' | ''
        end

        with_them do
          let(:order_by) { "#{field} #{direction}" }

          it_behaves_like 'returning an error service response',
            message: described_class::INVALID_ORDER_BY_ERROR_RESPONSE.message
        end
      end
    end

    private

    def dummy_list_response
      ::Google::Cloud::ArtifactRegistry::V1::ListDockerImagesResponse.new(
        docker_images: [::Google::Cloud::ArtifactRegistry::V1::DockerImage.new(name: 'test')],
        next_page_token: 'next_page_token'
      )
    end
  end
end
