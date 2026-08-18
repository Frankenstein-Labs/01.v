# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::GoogleCloudPlatform::ArtifactRegistry, feature_category: :package_registry do
  let_it_be_with_reload(:project) { create(:project) }

  it_behaves_like Integrations::HasAvatar

  subject(:integration) { build_stubbed(:google_cloud_platform_artifact_registry_integration, project: project) }

  describe 'attributes' do
    describe 'default values' do
      it { is_expected.not_to be_alert_events }
      it { is_expected.not_to be_commit_events }
      it { is_expected.not_to be_confidential_issues_events }
      it { is_expected.not_to be_confidential_note_events }
      it { is_expected.not_to be_issues_events }
      it { is_expected.not_to be_job_events }
      it { is_expected.not_to be_merge_requests_events }
      it { is_expected.not_to be_note_events }
      it { is_expected.not_to be_pipeline_events }
      it { is_expected.not_to be_push_events }
      it { is_expected.not_to be_tag_push_events }
      it { is_expected.not_to be_wiki_page_events }
      it { is_expected.not_to be_comment_on_event_enabled }
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:artifact_registry_project_id) }
    it { is_expected.to validate_presence_of(:artifact_registry_location) }
    it { is_expected.to validate_presence_of(:artifact_registry_repositories) }

    context 'when inactive integration' do
      subject(:integration) { build_stubbed(:google_cloud_platform_artifact_registry_integration, :inactive) }

      it { is_expected.not_to validate_presence_of(:artifact_registry_project_id) }
      it { is_expected.not_to validate_presence_of(:artifact_registry_location) }
      it { is_expected.not_to validate_presence_of(:artifact_registry_repositories) }
    end
  end

  describe '.title' do
    subject { described_class.title }

    it { is_expected.to eq(s_('GoogleCloud|Google Artifact Management')) }
  end

  describe '.description' do
    subject { described_class.description }

    it do
      is_expected.to eq(s_('GoogleCloud|Manage your artifacts in Google Artifact Registry.'))
    end
  end

  describe '.to_param' do
    subject { described_class.to_param }

    it { is_expected.to eq('google_cloud_platform_artifact_registry') }
  end

  describe '#artifact_registry_repository' do
    subject { integration.artifact_registry_repository }

    it { is_expected.to eq(integration.artifact_registry_repositories) }
  end

  describe '.supported_events' do
    subject { described_class.supported_events }

    it { is_expected.to eq([]) }
  end

  describe '.default_test_event' do
    subject { described_class.default_test_event }

    it { is_expected.to eq('current_user') }
  end

  describe '#repository_full_name' do
    let(:expected) do
      "projects/#{integration.artifact_registry_project_id}/" \
        "locations/#{integration.artifact_registry_location}/" \
        "repositories/#{integration.artifact_registry_repository}"
    end

    subject { integration.repository_full_name }

    it { is_expected.to eq(expected) }
  end

  describe '#testable?' do
    subject { integration.testable? }

    it { is_expected.to be_truthy }
  end

  describe '#ci_variables' do
    subject { integration.ci_variables }

    it { is_expected.to eq([]) }

    context 'with saas only enabled' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'when integration is inactive' do
        let(:integration) { build_stubbed(:google_cloud_platform_artifact_registry_integration, :inactive) }

        it { is_expected.to eq([]) }
      end

      context 'when integration is active' do
        it do
          is_expected.to contain_exactly(
            { key: 'GOOGLE_ARTIFACT_REGISTRY_PROJECT_ID',
              value: integration.artifact_registry_project_id },
            { key: 'GOOGLE_ARTIFACT_REGISTRY_REPOSITORY_NAME',
              value: integration.artifact_registry_repository },
            { key: 'GOOGLE_ARTIFACT_REGISTRY_REPOSITORY_LOCATION',
              value: integration.artifact_registry_location }
          )
        end
      end
    end
  end

  describe '#sections' do
    subject { integration.sections }

    it { is_expected.to eq([{ type: 'google_artifact_management' }]) }
  end

  describe '#test' do
    let_it_be(:integration) { create(:google_cloud_platform_artifact_registry_integration) }

    let_it_be(:wlif_integration) do
      create(:google_cloud_platform_workload_identity_federation_integration, project: integration.project)
    end

    let(:client_double) { instance_double('::GoogleCloud::ArtifactRegistry::Client') }
    let(:user) { integration.project.first_owner }
    let(:data) { { current_user: user } }

    subject { integration.test(data) }

    before do
      stub_saas_features(google_cloud_support: true)

      allow(::GoogleCloud::ArtifactRegistry::Client).to receive(:new)
        .with(wlif_integration: wlif_integration, user: user).and_return(client_double)

      allow(client_double).to receive(:repository)
        .and_return(dummy_repository_response)
    end

    it { is_expected.to eq(success: true, result: nil) }

    context 'when the connection was not established' do
      before do
        allow(client_double).to receive(:repository)
          .and_raise(::GoogleCloud::ApiError)
      end

      it { is_expected.to eq(success: false, result: 'Unsuccessful Google Cloud API request') }
    end

    private

    def dummy_repository_response
      ::Google::Cloud::ArtifactRegistry::V1::Repository.new(name: 'test')
    end
  end
end
