# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Google Artifact Registry', :js, feature_category: :container_registry do
  include GoogleApi::CloudPlatformHelpers
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, developers: user) }
  let_it_be_with_refind(:artifact_registry_integration) do
    create(:google_cloud_platform_artifact_registry_integration, project: project)
  end

  let_it_be_with_refind(:wlif_integration) do
    create(:google_cloud_platform_workload_identity_federation_integration, project: project)
  end

  let_it_be(:artifact_registry_repository_url) do
    "https://console.cloud.google.com/artifacts/docker/#{artifact_registry_integration.artifact_registry_project_id}/" \
      "#{artifact_registry_integration.artifact_registry_location}/" \
      "#{artifact_registry_integration.artifact_registry_repository}"
  end

  let(:image) { 'ruby' }
  let(:digest) { 'sha256:4ca5c21b' }
  let(:client_double) { instance_double('::GoogleCloud::ArtifactRegistry::Client') }
  let(:page_token) { nil }
  let(:order_by) { 'update_time desc' }
  let(:page_size) { nil }
  let(:default_page_size) { ::GoogleCloud::ArtifactRegistry::ListDockerImagesService::DEFAULT_PAGE_SIZE }
  let(:next_page_token) { 'next_page_token' }
  let(:name) do
    "projects/#{artifact_registry_integration.artifact_registry_project_id}/" \
      "locations/#{artifact_registry_integration.artifact_registry_location}/" \
      "repositories/#{artifact_registry_integration.artifact_registry_repository}/" \
      "dockerImages/#{image}@#{digest}"
  end

  let(:docker_image) do
    Google::Cloud::ArtifactRegistry::V1::DockerImage.new(
      name: name,
      uri: "us-east1-docker.pkg.dev/#{artifact_registry_integration.artifact_registry_project_id}/" \
           "demo/#{image}@#{digest}",
      tags: ['97c58898'],
      image_size_bytes: 304_121_628,
      media_type: 'application/vnd.docker.distribution.manifest.v2+json',
      build_time: Time.now.utc,
      update_time: Time.now.utc,
      upload_time: Time.now.utc
    )
  end

  before do
    stub_saas_features(google_cloud_support: true)

    allow(::GoogleCloud::ArtifactRegistry::Client).to receive(:new)
      .with(wlif_integration: wlif_integration, user: user)
      .and_return(client_double)

    allow(client_double).to receive(:docker_images)
      .with(page_token: page_token, page_size: page_size || default_page_size, order_by: order_by)
      .and_return(dummy_list_docker_images_response)
    sign_in(user)
  end

  it 'passes axe automated accessibility testing' do
    visit_page

    expect(page).to have_content(image)
    expect(page).to be_axe_clean.within_testid('artifact-registry-list-page')
  end

  it 'has a page title set' do
    visit_page

    expect(page).to have_title _('Google Artifact Registry')
  end

  it 'has external link to google cloud' do
    visit_page

    expect(page).to have_link _('Open in Google Cloud')
  end

  describe 'link to settings' do
    context 'when user is not a group owner' do
      it 'does not show group settings link' do
        visit_page

        expect(page).not_to have_link('Configure in settings',
          href: edit_project_settings_integration_path(project, ::Integrations::GoogleCloudPlatform::ArtifactRegistry))
      end
    end

    context 'when user is a group maintainer' do
      before_all do
        project.add_maintainer(user)
      end

      it 'shows group settings link' do
        visit_page

        expect(page).to have_link('Configure in settings',
          href: edit_project_settings_integration_path(project, ::Integrations::GoogleCloudPlatform::ArtifactRegistry))
      end
    end
  end

  describe 'details page' do
    before do
      allow(client_double).to receive(:docker_image).with(name: name).and_return(docker_image)
    end

    it 'has a page title set', :aggregate_failures do
      visit project_google_cloud_artifact_registry_image_path(project, {
        image: "#{image}@#{digest}",
        project: artifact_registry_integration.artifact_registry_project_id,
        repository: artifact_registry_integration.artifact_registry_repository,
        location: artifact_registry_integration.artifact_registry_location
      })

      expect(find_by_testid('breadcrumb-links')).to have_link 'ruby@4ca5c21b'

      expect(page).to have_text _('ruby@4ca5c21b')
      expect(page).to have_link _('Open in Google Cloud')
      expect(page).to have_button _('Copy image path')
      expect(page).to have_button _('Copy digest')
    end
  end

  private

  def visit_page
    visit project_google_cloud_artifact_registry_index_path(project)
  end

  def dummy_list_docker_images_response
    Google::Cloud::ArtifactRegistry::V1::ListDockerImagesResponse.new(
      docker_images: [docker_image],
      next_page_token: 'next_page_token'
    )
  end
end
