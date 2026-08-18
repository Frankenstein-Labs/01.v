# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::PipelineEligibilityService, feature_category: :security_policy_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :small_repo, group: namespace) }
  let_it_be(:scan_profile) do
    create(:security_scan_profile, namespace: namespace, name: 'SAST Profile', scan_type: :sast, projects: [project])
  end

  let(:ref) { "refs/heads/#{project.default_branch}" }
  let(:pipeline_source) { :push }
  let(:service) { described_class.new(project: project, ref: ref, pipeline_source: pipeline_source) }

  describe '#eligible?' do
    subject(:eligible) { service.eligible? }

    shared_examples 'checks security_scan_profiles licensed feature' do
      before do
        stub_licensed_features(security_scan_profiles: false)
      end

      it { is_expected.to be false }
    end

    before do
      stub_licensed_features(security_scan_profiles: true)
    end

    context 'when no triggers exist' do
      it { is_expected.to be false }
    end

    context 'when triggers exist for default branch' do
      before_all do
        create(:security_scan_profile_trigger,
          namespace: namespace,
          scan_profile: scan_profile,
          trigger_type: :default_branch_pipeline)
      end

      it_behaves_like 'checks security_scan_profiles licensed feature'

      it { is_expected.to be true }

      context 'when ref is not the default branch' do
        let(:ref) { 'refs/heads/feature-branch' }

        it { is_expected.to be false }
      end

      context 'when the profile is soft-deleted' do
        before do
          Security::ScanProfile.find(scan_profile.id).destroy!
        end

        it { is_expected.to be false }
      end
    end

    context 'when triggers exist for merge request' do
      let(:pipeline_source) { :merge_request_event }
      let(:ref) { 'refs/heads/feature-branch' }

      before_all do
        create(:security_scan_profile_trigger,
          namespace: namespace,
          scan_profile: scan_profile,
          trigger_type: :merge_request_pipeline)
      end

      it_behaves_like 'checks security_scan_profiles licensed feature'

      it { is_expected.to be true }

      context 'when source is not merge_request_event' do
        let(:pipeline_source) { :push }

        it { is_expected.to be false }
      end
    end

    context 'when project is nil' do
      let(:project) { nil }
      let(:ref) { 'refs/heads/main' }

      it { is_expected.to be false }
    end

    context 'when pipeline_source is nil' do
      let(:pipeline_source) { nil }

      it { is_expected.to be false }
    end
  end

  describe '#applicable_profiles_triggers' do
    subject(:applicable_triggers) { service.applicable_profiles_triggers }

    let_it_be(:default_branch_trigger) do
      create(:security_scan_profile_trigger,
        namespace: namespace,
        scan_profile: scan_profile,
        trigger_type: :default_branch_pipeline)
    end

    let_it_be(:mr_trigger) do
      create(:security_scan_profile_trigger,
        namespace: namespace,
        scan_profile: scan_profile,
        trigger_type: :merge_request_pipeline)
    end

    before do
      stub_licensed_features(security_scan_profiles: true)
    end

    context 'when pipeline is for merge request' do
      let(:pipeline_source) { :merge_request_event }
      let(:ref) { 'refs/heads/feature-branch' }

      it 'returns only merge request pipeline triggers' do
        expect(applicable_triggers).to contain_exactly(mr_trigger)
      end
    end

    context 'when pipeline is for default branch' do
      it 'returns only default branch pipeline triggers' do
        expect(applicable_triggers).to contain_exactly(default_branch_trigger)
      end
    end

    context 'when ref is a non-default branch' do
      let(:ref) { 'refs/heads/feature-branch' }

      it 'returns no triggers' do
        expect(applicable_triggers).to be_empty
      end
    end

    context 'when ref is a tag' do
      let(:ref) { 'refs/tags/v1.0.0' }

      it 'returns no triggers' do
        expect(applicable_triggers).to be_empty
      end
    end

    context 'when ref is nil' do
      let(:ref) { nil }

      it 'returns no triggers' do
        expect(applicable_triggers).to be_empty
      end
    end
  end
end
