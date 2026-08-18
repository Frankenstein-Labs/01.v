# frozen_string_literal: true

require 'spec_helper'
require 'google/cloud/artifact_registry/v1'

RSpec.describe 'getting the google cloud docker images linked to a project', :freeze_time, feature_category: :container_registry do
  include GraphqlHelpers
  include GoogleApi::CloudPlatformHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_refind(:wlif_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: project)
  end

  let_it_be_with_refind(:artifact_registry_integration) do
    create(:google_cloud_platform_artifact_registry_integration, project: project)
  end

  let_it_be(:artifact_registry_repository_url) do
    "https://console.cloud.google.com/artifacts/docker/#{artifact_registry_integration.artifact_registry_project_id}/" \
      "#{artifact_registry_integration.artifact_registry_location}/" \
      "#{artifact_registry_integration.artifact_registry_repository}"
  end

  let(:user) { project.first_owner }
  let(:image) { 'ruby' }
  let(:digest) { 'sha256:4ca5c21b' }
  let(:client_double) { instance_double('::GoogleCloud::ArtifactRegistry::Client') }
  let(:page_token) { nil }
  let(:order_by) { nil }
  let(:page_size) { nil }
  let(:default_page_size) { ::GoogleCloud::ArtifactRegistry::ListDockerImagesService::DEFAULT_PAGE_SIZE }
  let(:next_page_token) { 'next_page_token' }

  let(:docker_image) do
    Google::Cloud::ArtifactRegistry::V1::DockerImage.new(
      name: "projects/#{artifact_registry_integration.artifact_registry_project_id}/" \
            "locations/#{artifact_registry_integration.artifact_registry_location}/" \
            "repositories/#{artifact_registry_integration.artifact_registry_repository}/" \
            "dockerImages/#{image}@#{digest}",
      uri: "us-east1-docker.pkg.dev/#{artifact_registry_integration.artifact_registry_project_id}/" \
           "demo/#{image}@#{digest}",
      tags: ['97c58898'],
      image_size_bytes: 304_121_628,
      media_type: 'application/vnd.docker.distribution.manifest.v2+json',
      build_time: Time.now,
      update_time: Time.now,
      upload_time: Time.now
    )
  end

  let(:fields) do
    <<~QUERY
      projectId,
      repository,
      artifactRegistryRepositoryUrl,
      #{query_graphql_field('artifacts', params, artifacts_fields)}
    QUERY
  end

  let(:artifacts_fields) do
    <<~QUERY
      nodes {
        #{query_graphql_fragment('google_cloud_artifact_registry_docker_image'.classify)}
      }
      pageInfo {
        hasNextPage,
        startCursor,
        endCursor
      }
    QUERY
  end

  let(:params) do
    {}
  end

  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('googleCloudArtifactRegistryRepository', {}, fields)
    )
  end

  let(:repository_response) do
    graphql_data_at(:project, :google_cloud_artifact_registry_repository)
  end

  subject(:request) { post_graphql(query, current_user: user) }

  before do
    stub_saas_features(google_cloud_support: true)

    allow(::GoogleCloud::ArtifactRegistry::Client).to receive(:new)
      .with(wlif_integration: wlif_integration, user: user
      ).and_return(client_double)

    allow(client_double).to receive(:docker_images)
      .with(page_token: page_token, page_size: page_size || default_page_size, order_by: order_by)
      .and_return(dummy_list_docker_images_response)
  end

  shared_examples 'returning the expected response' do |start_cursor: nil, end_cursor: nil|
    it 'returns the proper response' do
      request

      expect(repository_response).to eq({
        'projectId' => artifact_registry_integration.artifact_registry_project_id,
        'repository' => artifact_registry_integration.artifact_registry_repository,
        'artifactRegistryRepositoryUrl' => artifact_registry_repository_url,
        'artifacts' => {
          'nodes' => [{
            'name' => docker_image.name,
            'tags' => docker_image.tags,
            'uri' => docker_image.uri,
            'uploadTime' => Time.now.iso8601,
            'updateTime' => Time.now.iso8601,
            'image' => image,
            'digest' => digest
          }],
          'pageInfo' => {
            'endCursor' => end_cursor,
            'hasNextPage' => true,
            'startCursor' => start_cursor
          }
        }
      })
    end
  end

  shared_examples 'returns the error' do |message|
    it do
      request

      expect_graphql_errors_to_include(message)
    end
  end

  it_behaves_like 'a working graphql query' do
    before do
      request
    end
  end

  it 'matches the JSON schema' do
    request

    expect(repository_response).to match_schema('graphql/google_cloud/artifact_registry/repository')
  end

  it_behaves_like 'returning the expected response', end_cursor: 'next_page_token'

  context 'with arguments' do
    let(:page_token) { 'prev_page_token' }
    let(:order_by) { 'update_time desc' }
    let(:page_size) { 10 }

    let(:params) do
      { sort: :UPDATE_TIME_DESC, after: page_token, first: page_size }
    end

    it_behaves_like 'returning the expected response', end_cursor: 'next_page_token', start_cursor: 'prev_page_token'

    context 'with invalid `sort` argument' do
      let(:params) do
        { sort: :INVALID }
      end

      it 'returns the error' do
        request

        expect_graphql_errors_to_include(
          "Argument 'sort' on Field 'artifacts' " \
          "has an invalid value (INVALID). Expected type 'GoogleCloudArtifactRegistryArtifactsSort'."
        )
      end
    end
  end

  context 'when an user does not have required permissions' do
    let(:user) { create(:user, guest_of: project) }

    it { is_expected.to be_nil }
  end

  context 'with an anonymous user on a public project' do
    let(:user) { nil }

    before do
      project.update!(visibility: Gitlab::VisibilityLevel::PUBLIC)
    end

    it { is_expected.to be_nil }
  end

  context 'when google artifact registry feature is unavailable' do
    before do
      stub_saas_features(google_cloud_support: false)
    end

    it { is_expected.to be_nil }
  end

  context 'with the Google Cloud Identity and Access Management (IAM) project integration' do
    context 'when does not exist' do
      before do
        wlif_integration.destroy!
      end

      it_behaves_like 'returns the error',
        "#{Integrations::GoogleCloudPlatform::WorkloadIdentityFederation.title} integration not set"
    end

    context 'when inactive' do
      before do
        wlif_integration.update_column(:active, false)
      end

      it_behaves_like 'returns the error',
        "#{Integrations::GoogleCloudPlatform::WorkloadIdentityFederation.title} integration not active"
    end
  end

  context 'with the Google Artifact Management integration' do
    context 'when does not exist' do
      before do
        artifact_registry_integration.destroy!
      end

      it_behaves_like 'returns the error',
        "#{Integrations::GoogleCloudPlatform::ArtifactRegistry.title} integration does not exist or inactive"
    end

    context 'when inactive' do
      before do
        artifact_registry_integration.update_column(:active, false)
      end

      it_behaves_like 'returns the error',
        "#{Integrations::GoogleCloudPlatform::ArtifactRegistry.title} integration does not exist or inactive"
    end
  end

  def dummy_list_docker_images_response
    Google::Cloud::ArtifactRegistry::V1::ListDockerImagesResponse.new(
      docker_images: [docker_image],
      next_page_token: 'next_page_token'
    )
  end
end
