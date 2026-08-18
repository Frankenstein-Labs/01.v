# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::GoogleCloudPlatform::WorkloadIdentityFederation, feature_category: :system_access do
  it_behaves_like Integrations::HasAvatar

  subject(:integration) { build_stubbed(:google_cloud_platform_workload_identity_federation_integration) }

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
    it { is_expected.to validate_presence_of(:workload_identity_federation_project_id) }
    it { is_expected.to validate_presence_of(:workload_identity_federation_project_number) }
    it { is_expected.to validate_presence_of(:workload_identity_pool_id) }
    it { is_expected.to validate_presence_of(:workload_identity_pool_provider_id) }
    it { is_expected.to validate_numericality_of(:workload_identity_federation_project_number).only_integer }

    it { is_expected.to allow_value('my-sample-project-191923').for(:workload_identity_federation_project_id) }
    it { is_expected.to allow_value('my-sample-project-191923').for(:workload_identity_pool_id) }
    it { is_expected.to allow_value('my-sample-project-191923').for(:workload_identity_pool_provider_id) }

    it { is_expected.not_to allow_value('My-Sample-Project-191923').for(:workload_identity_federation_project_id) }
    it { is_expected.not_to allow_value('non allowed value').for(:workload_identity_pool_id) }
    it { is_expected.not_to allow_value('"" only letters or numbers ""').for(:workload_identity_pool_provider_id) }

    context 'when inactive integration' do
      subject(:integration) do
        build_stubbed(:google_cloud_platform_workload_identity_federation_integration, :inactive)
      end

      it { is_expected.not_to validate_presence_of(:workload_identity_federation_project_id) }
      it { is_expected.not_to validate_presence_of(:workload_identity_federation_project_number) }
      it { is_expected.not_to validate_presence_of(:workload_identity_pool_id) }
      it { is_expected.not_to validate_presence_of(:workload_identity_pool_provider_id) }
    end
  end

  describe '.title' do
    subject { described_class.title }

    it { is_expected.to eq(s_('GoogleCloud|Google Cloud IAM')) }
  end

  describe '.description' do
    subject { described_class.description }

    it do
      is_expected.to eq(s_(
        'GoogleCloud|Manage permissions for Google Cloud resources with Identity and Access Management (IAM).'
      ))
    end
  end

  describe '.to_param' do
    subject { described_class.to_param }

    it { is_expected.to eq('google_cloud_platform_workload_identity_federation') }
  end

  describe '.supported_events' do
    subject { described_class.supported_events }

    it { is_expected.to eq([]) }
  end

  describe '.wlif_issuer_url' do
    context 'when call with a group' do
      subject { described_class.wlif_issuer_url(group) }

      let_it_be(:root_group) { create(:group) }
      let_it_be(:group) { create(:group, parent: root_group) }

      it { is_expected.to start_with('https://') }
      it { is_expected.to end_with("/oidc/#{group.root_ancestor.path}") }
      it { is_expected.not_to include(group.path) }
    end

    context 'when call with a project' do
      subject { described_class.wlif_issuer_url(project) }

      let_it_be(:project) { create(:project, :in_subgroup) }

      it { is_expected.to start_with('https://') }
      it { is_expected.to end_with("/oidc/#{project.root_ancestor.path}") }
      it { is_expected.not_to include(project.path) }
    end
  end

  describe '.jwt_claim_mapping' do
    subject { described_class.jwt_claim_mapping }

    it { is_expected.to match(a_hash_including('attribute.developer_access' => 'assertion.developer_access')) }
    it { is_expected.to match(a_hash_including('attribute.namespace_path' => 'assertion.namespace_path')) }
    it { is_expected.to match(a_hash_including('attribute.user_access_level' => 'assertion.user_access_level')) }
    it { is_expected.to match(a_hash_including('google.subject' => 'assertion.sub')) }
  end

  describe '.jwt_claim_mapping_script_value' do
    subject { described_class.jwt_claim_mapping_script_value }

    it { is_expected.to include('attribute.maintainer_access=assertion.maintainer_access,') }
    it { is_expected.to include(',attribute.project_path=assertion.project_path,') }
    it { is_expected.to include(',google.subject=assertion.sub') }
    it { is_expected.not_to include(' ') }
  end

  describe '#testable?' do
    subject { integration.testable? }

    it { is_expected.to be_falsey }
  end

  describe '#identity_provider_resource_name' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:group) { create(:group) }
    let_it_be(:project_integration, freeze: false) do
      create(:google_cloud_platform_workload_identity_federation_integration)
    end

    let_it_be(:group_integration, freeze: false) do
      create(:google_cloud_platform_workload_identity_federation_integration, project: nil, group: group)
    end

    let(:expected_resource_name) do
      "//iam.googleapis.com/projects/#{integration.workload_identity_federation_project_number}/" \
        "locations/global/workloadIdentityPools/#{integration.workload_identity_pool_id}/" \
        "providers/#{integration.workload_identity_pool_provider_id}"
    end

    subject { integration.identity_provider_resource_name }

    where(:integration, :active) do
      ref(:project_integration) | true
      ref(:project_integration) | false
      ref(:group_integration) | true
      ref(:group_integration) | false
    end

    with_them do
      before do
        integration.update!(active: active) unless active
      end

      it { is_expected.to be_nil }

      context 'when feature is available' do
        before do
          stub_saas_features(google_cloud_support: true)
        end

        if params[:active]
          it { is_expected.to eq(expected_resource_name) }
        else
          it { is_expected.to be_nil }
        end
      end
    end
  end

  describe '#identity_pool_resource_name' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:group) { create(:group) }
    let_it_be(:project_integration, freeze: false) do
      create(:google_cloud_platform_workload_identity_federation_integration)
    end

    let_it_be(:group_integration, freeze: false) do
      create(:google_cloud_platform_workload_identity_federation_integration, project: nil, group: group)
    end

    let(:resource_name) do
      "iam.googleapis.com/projects/#{integration.workload_identity_federation_project_number}/" \
        "locations/global/workloadIdentityPools/#{integration.workload_identity_pool_id}"
    end

    subject { integration.identity_pool_resource_name }

    where(:integration, :active, :expected_resource_name) do
      ref(:project_integration) | true | ref(:resource_name)
      ref(:project_integration) | false | nil
      ref(:group_integration) | true | ref(:resource_name)
      ref(:group_integration) | false | nil
    end

    with_them do
      before do
        integration.update!(active: active) unless active
      end

      it { is_expected.to be_nil }

      context 'when feature is available' do
        before do
          stub_saas_features(google_cloud_support: true)
        end

        it { is_expected.to eq(expected_resource_name) }
      end
    end
  end
end
