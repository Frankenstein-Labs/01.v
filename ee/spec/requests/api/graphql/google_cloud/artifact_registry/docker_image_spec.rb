# frozen_string_literal: true

require 'spec_helper'
require 'google/cloud/artifact_registry/v1'

RSpec.describe 'getting the google cloud docker image linked to a project', :freeze_time, feature_category: :container_registry do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project) }

  let_it_be_with_refind(:artifact_registry_integration) do
    create(
      :google_cloud_platform_artifact_registry_integration,
      project: project,
      artifact_registry_repositories: 'demo'
    )
  end

  let_it_be_with_refind(:wlif_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: project)
  end

  let_it_be(:user) { project.first_owner }

  let(:location) { artifact_registry_integration.artifact_registry_location }
  let(:google_cloud_project_id) { artifact_registry_integration.artifact_registry_project_id }
  let(:repository) { artifact_registry_integration.artifact_registry_repository }
  let(:image) { 'ruby' }
  let(:digest) { 'sha256:4ca5c21b' }
  let(:client_double) { instance_double('::GoogleCloud::ArtifactRegistry::Client') }

  let(:uri) do
    "#{location}-docker.pkg.dev/#{google_cloud_project_id}/" \
      "#{artifact_registry_integration.artifact_registry_repository}/#{image}@#{digest}"
  end

  let(:name) do
    "projects/#{google_cloud_project_id}/" \
      "locations/#{location}/" \
      "repositories/#{repository}/" \
      "dockerImages/#{image}@#{digest}"
  end

  let(:docker_image) do
    Google::Cloud::ArtifactRegistry::V1::DockerImage.new(
      name: name,
      uri: uri,
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
      #{query_graphql_fragment('GoogleCloudArtifactRegistryDockerImageDetails')}
    QUERY
  end

  let(:params) do
    {
      google_cloud_project_id: google_cloud_project_id,
      location: location,
      repository: repository,
      image: "#{image}@#{digest}",
      projectPath: project.full_path
    }
  end

  let(:query) do
    graphql_query_for(
      'googleCloudArtifactRegistryRepositoryArtifact', params, fields
    )
  end

  let(:artifact_response) do
    graphql_data_at(:google_cloud_artifact_registry_repository_artifact)
  end

  subject(:request) { post_graphql(query, current_user: user) }

  before do
    stub_saas_features(google_cloud_support: true)

    allow(::GoogleCloud::ArtifactRegistry::Client).to receive(:new)
      .with(wlif_integration: wlif_integration, user: user)
      .and_return(client_double)

    allow(client_double).to receive(:docker_image).with(name: name).and_return(docker_image)
  end

  shared_examples 'returning the expected response' do
    it 'returns the proper response' do
      request

      expect(artifact_response).to eq({
        'name' => docker_image.name,
        'uri' => docker_image.uri,
        'tags' => docker_image.tags,
        'imageSizeBytes' => docker_image.image_size_bytes.to_s,
        'mediaType' => docker_image.media_type,
        'buildTime' => Time.now.iso8601,
        'updateTime' => Time.now.iso8601,
        'uploadTime' => Time.now.iso8601,
        'projectId' => google_cloud_project_id,
        'location' => location,
        'repository' => repository,
        'image' => image,
        'digest' => digest,
        'artifactRegistryImageUrl' => "https://#{uri}"
      })
    end
  end

  shared_examples 'returning a blank response' do
    it 'returns a blank response' do
      subject

      expect(artifact_response).to be_blank
    end
  end

  it_behaves_like 'a working graphql query' do
    before do
      request
    end
  end

  it 'matches the JSON schema' do
    request

    expect(artifact_response).to match_schema('graphql/google_cloud/artifact_registry/docker_image_details')
  end

  it_behaves_like 'returning the expected response'

  context 'when an user does not have required permissions' do
    let(:user) { create(:user, guest_of: project) }

    it_behaves_like 'returning a blank response'
  end

  context 'with an anonymous user on a public project' do
    let(:user) { nil }

    before do
      project.update!(visibility: Gitlab::VisibilityLevel::PUBLIC)
    end

    it_behaves_like 'returning a blank response'
  end

  context 'when google artifact registry feature is unavailable' do
    before do
      stub_saas_features(google_cloud_support: false)
    end

    it_behaves_like 'returning a blank response'
  end

  %i[wlif artifact_registry].each do |integration_type|
    context "with the #{integration_type} integration" do
      let(:integration) { public_send("#{integration_type}_integration") }

      context 'when not present' do
        before do
          integration.destroy!
        end

        it_behaves_like 'returning a blank response'
      end

      context 'when inactive' do
        before do
          integration.update_column(:active, false)
        end

        it_behaves_like 'returning a blank response'
      end
    end
  end

  context 'with invalid arguments' do
    using RSpec::Parameterized::TableSyntax

    # rubocop:disable Layout/LineLength -- The table rows are more readable without line breaks
    where(:argument, :error_message) do
      :location | "`location` doesn't match Repository location of Google Artifact Management integration"
      :repository | "`repository` doesn't match Repository name of Google Artifact Management integration"
      :google_cloud_project_id | "`googleCloudProjectId` doesn't match Google Cloud project ID of Google Artifact Management integration"
    end
    # rubocop:enable Layout/LineLength

    with_them do
      let(params[:argument]) { 'invalid' }

      before do
        request
      end

      it 'returns the error' do
        expect_graphql_errors_to_include(error_message)
      end
    end
  end
end
