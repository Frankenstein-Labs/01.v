# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GoogleCloud::ArtifactRegistry::Client, feature_category: :container_registry do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }
  let_it_be(:rsa_key_data) { rsa_key.to_s }
  let_it_be_with_refind(:wlif_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: project)
  end

  let_it_be_with_refind(:artifact_registry_integration) do
    create(:google_cloud_platform_artifact_registry_integration, project: project)
  end

  let(:user) { project.owner }
  let(:artifact_registry_location) { artifact_registry_integration&.artifact_registry_location }
  let(:artifact_registry_repository) { artifact_registry_integration&.artifact_registry_repository }
  let(:client) { described_class.new(wlif_integration: wlif_integration, user: user) }
  let(:expected_metadata) { { 'user-agent' => "gitlab-rails-dot-com:google-cloud-integration/#{Gitlab::VERSION}" } }

  shared_context 'with a client double' do
    let(:config_double) do
      instance_double('Google::Cloud::ArtifactRegistry::V1::ArtifactRegistry::Client::Configuration')
    end

    let(:rpcs_double) do
      instance_double('Google::Cloud::ArtifactRegistry::V1::ArtifactRegistry::Client::Configuration::Rpcs')
    end

    let(:rpc_list_docker_images_double) { instance_double('Gapic::Config::Method') }
    let(:rpc_get_docker_image_double) { instance_double('Gapic::Config::Method') }
    let(:client_double) { instance_double('::Google::Cloud::ArtifactRegistry::V1::ArtifactRegistry::Client') }
    let(:dummy_response) { Object.new }

    before do
      stub_saas_features(google_cloud_support: true)
      stub_application_setting(ci_jwt_signing_key: rsa_key_data)
      stub_authentication_requests

      allow(config_double).to receive(:credentials=)
        .with(instance_of(::Google::Cloud::ArtifactRegistry::V1::ArtifactRegistry::Credentials))
      allow(config_double).to receive(:rpcs).and_return(rpcs_double)
      allow(rpcs_double).to receive(:list_docker_images).and_return(rpc_list_docker_images_double)
      allow(rpcs_double).to receive(:get_docker_image).and_return(rpc_get_docker_image_double)
      allow(rpc_list_docker_images_double).to receive(:metadata=)
      allow(rpc_get_docker_image_double).to receive(:metadata=)
      allow(::Google::Cloud::ArtifactRegistry::V1::ArtifactRegistry::Client).to receive(:new) do |_, &block|
        block.call(config_double)
        client_double
      end

      # required so that google auth gem will not trigger any API request
      allow(wlif_integration).to receive(:identity_provider_resource_name)
          .and_return('//identity.provider.resource.name.test')
    end
  end

  it_behaves_like 'handling google cloud client common validations' do
    context 'with a nil artifact registry integration' do
      before do
        artifact_registry_integration.destroy!
      end

      it_behaves_like 'raising an error with', ArgumentError, described_class::ARTIFACT_REGISTRY_INTEGRATION_DISABLED
    end

    context 'with a disabled integration' do
      before do
        artifact_registry_integration.update_column(:active, false)
      end

      it_behaves_like 'raising an error with', ArgumentError, described_class::ARTIFACT_REGISTRY_INTEGRATION_DISABLED
    end
  end

  describe '#repository' do
    include_context 'with a client double'

    subject(:repository) { client.repository }

    it 'returns the expected response' do
      expect(client_double).to receive(:get_repository)
        .with(instance_of(::Google::Cloud::ArtifactRegistry::V1::GetRepositoryRequest))
        .and_return(dummy_response)

      expect(repository).to eq(dummy_response)
    end

    it_behaves_like 'handling google cloud client common errors', client_method: :get_repository
  end

  describe '#docker_images' do
    include_context 'with a client double'

    let(:page_size) { nil }
    let(:page_token) { nil }
    let(:order_by) { nil }
    let(:list_response) do
      instance_double(
        'Gapic::PagedEnumerable',
        response: { docker_images: dummy_response, next_page_token: 'token' }
      )
    end

    subject(:docker_images) { client.docker_images(page_size: page_size, page_token: page_token, order_by: order_by) }

    shared_examples 'returning the expected response' do |expected_page_size: described_class::DEFAULT_PAGE_SIZE|
      it 'returns the expected response' do
        expect(rpc_list_docker_images_double).to receive(:metadata=).with(expected_metadata)
        expect(client_double).to receive(:list_docker_images) do |request|
          expect(request).to be_a ::Google::Cloud::ArtifactRegistry::V1::ListDockerImagesRequest
          expect(request.page_size).to eq(expected_page_size)
          expect(request.page_token).to eq(page_token.to_s)
          expect(request.order_by).to eq(order_by.to_s)

          list_response
        end

        expect(docker_images).to eq(docker_images: dummy_response, next_page_token: 'token')
      end
    end

    it_behaves_like 'returning the expected response'

    context 'with a page size set' do
      let(:page_size) { 20 }

      it_behaves_like 'returning the expected response', expected_page_size: 20
    end

    context 'with a page token set' do
      let(:page_token) { 'token' }

      it_behaves_like 'returning the expected response'
    end

    context 'with an order by set' do
      let(:order_by) { :name }

      it_behaves_like 'returning the expected response'
    end

    it_behaves_like 'handling google cloud client common errors', client_method: :list_docker_images
  end

  describe '#docker_image' do
    include_context 'with a client double'

    let(:name) { 'test' }

    subject(:docker_image) { client.docker_image(name: name) }

    it 'returns the expected response' do
      expect(rpc_get_docker_image_double).to receive(:metadata=).with(expected_metadata)
      expect(client_double).to receive(:get_docker_image) do |request|
        expect(request).to be_a ::Google::Cloud::ArtifactRegistry::V1::GetDockerImageRequest
        expect(request.name).to eq(name)

        dummy_response
      end

      expect(docker_image).to eq(dummy_response)
    end

    it_behaves_like 'handling google cloud client common errors', client_method: :get_docker_image
  end

  def stub_authentication_requests
    stub_request(:get, ::GoogleCloud::GLGO_TOKEN_ENDPOINT_URL)
      .to_return(status: 200, body: ::Gitlab::Json.dump(token: 'token'))
    stub_request(:post, ::GoogleCloud::STS_URL)
      .to_return(status: 200, body: ::Gitlab::Json.dump(token: 'token'))
  end
end
