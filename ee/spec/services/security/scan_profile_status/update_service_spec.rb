# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfileStatus::UpdateService, feature_category: :security_testing_configuration do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :small_repo, group: group) }
  let_it_be(:scan_profile) do
    create(:security_scan_profile, namespace: group, scan_type: :sast, projects: [project])
  end

  let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project, ref: project.default_branch) }

  subject(:execute) { described_class.new(pipeline).execute }

  before do
    stub_licensed_features(security_scan_profiles: true)
  end

  shared_examples 'does not update any status' do
    it 'does not create or update status records' do
      expect { execute }.not_to change { Security::ScanProfileProjectStatus.count }
    end
  end

  context 'when pipeline is nil' do
    subject(:execute) { described_class.new(nil).execute }

    it 'does nothing' do
      expect { execute }.not_to raise_error
    end
  end

  context 'when pipeline has profile-triggered builds' do
    let!(:build) do
      create(:ci_build, :success, pipeline: pipeline, project: project, name: 'sast-0').tap do |b|
        create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
      end
    end

    before do
      allow(::Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore)
        .to receive(:profile_id_for_build).and_return(scan_profile.id)
    end

    context 'when build succeeds' do
      it 'creates a status record with success' do
        execute

        status = Security::ScanProfileProjectStatus.find_by!(
          project_id: project.id,
          security_scan_profile_id: scan_profile.id
        )

        expect(status.status).to eq('success')
        expect(status.consecutive_success_count).to eq(1)
        expect(status.consecutive_failure_count).to eq(0)
        expect(status.build_id).to eq(build.id)
        expect(status.last_scan_at).to be_present
      end
    end

    context 'when build fails' do
      let!(:build) do
        create(:ci_build, :failed, pipeline: pipeline, project: project, name: 'sast-0').tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      it 'creates a status record with warning on first failure' do
        execute

        status = Security::ScanProfileProjectStatus.find_by!(
          project_id: project.id,
          security_scan_profile_id: scan_profile.id
        )

        expect(status.status).to eq('warning')
        expect(status.consecutive_failure_count).to eq(1)
        expect(status.consecutive_success_count).to eq(0)
      end
    end

    context 'when build fails consecutively' do
      let!(:build) do
        create(:ci_build, :failed, pipeline: pipeline, project: project, name: 'sast-0').tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      before do
        create(:scan_profile_project_status,
          project: project,
          scan_profile: scan_profile,
          status: :warning,
          consecutive_failure_count: 2,
          consecutive_success_count: 0
        )
      end

      it 'transitions to failed on 3rd consecutive failure' do
        execute

        status = Security::ScanProfileProjectStatus.find_by!(
          project_id: project.id,
          security_scan_profile_id: scan_profile.id
        )

        expect(status.status).to eq('failed')
        expect(status.consecutive_failure_count).to eq(3)
      end
    end

    context 'when build succeeds after failures' do
      before do
        create(:scan_profile_project_status,
          project: project,
          scan_profile: scan_profile,
          status: :warning,
          consecutive_failure_count: 2,
          consecutive_success_count: 0
        )
      end

      it 'resets to success' do
        execute

        status = Security::ScanProfileProjectStatus.find_by!(
          project_id: project.id,
          security_scan_profile_id: scan_profile.id
        )

        expect(status.status).to eq('success')
        expect(status.consecutive_failure_count).to eq(0)
        expect(status.consecutive_success_count).to eq(1)
      end
    end

    context 'when no existing status record exists and build succeeds' do
      it 'creates a new record with success' do
        execute

        status = Security::ScanProfileProjectStatus.find_by!(
          project_id: project.id,
          security_scan_profile_id: scan_profile.id
        )

        expect(status.status).to eq('success')
        expect(status.consecutive_success_count).to eq(1)
        expect(status.consecutive_failure_count).to eq(0)
      end
    end

    context 'when no existing status record exists and build fails' do
      let!(:build) do
        create(:ci_build, :failed, pipeline: pipeline, project: project, name: 'sast-0').tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      it 'creates a new record with warning and failure count 1' do
        execute

        status = Security::ScanProfileProjectStatus.find_by!(
          project_id: project.id,
          security_scan_profile_id: scan_profile.id
        )

        expect(status.status).to eq('warning')
        expect(status.consecutive_failure_count).to eq(1)
        expect(status.consecutive_success_count).to eq(0)
      end
    end

    context 'when Redis mapping is not available (fallback)' do
      let!(:build) do
        create(:ci_build, :success, pipeline: pipeline, project: project, name: 'sast-0',
          options: { artifacts: { reports: { sast: 'gl-sast-report.json' } } }
        ).tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      before do
        allow(::Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore)
          .to receive(:profile_id_for_build).and_return(nil)
      end

      it 'resolves profile ID from scan type' do
        execute

        status = Security::ScanProfileProjectStatus.find_by(
          project_id: project.id,
          security_scan_profile_id: scan_profile.id
        )

        expect(status).to be_present
        expect(status.status).to eq('success')
      end
    end

    context 'when Redis raises an error' do
      let!(:build) do
        create(:ci_build, :success, pipeline: pipeline, project: project, name: 'sast-0',
          options: { artifacts: { reports: { sast: 'gl-sast-report.json' } } }
        ).tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      before do
        allow(::Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore)
          .to receive(:profile_id_for_build).and_raise(::Redis::ConnectionError, 'Connection refused')
      end

      it 'falls back to DB resolution and tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception)
          .with(an_instance_of(::Redis::ConnectionError), hash_including(:extra))

        execute

        status = Security::ScanProfileProjectStatus.find_by(
          project_id: project.id,
          security_scan_profile_id: scan_profile.id
        )

        expect(status).to be_present
        expect(status.status).to eq('success')
      end
    end

    context 'when multiple profiles exist for the same scan type (fallback)' do
      let_it_be(:duplicate_profile) do
        create(:security_scan_profile, namespace: group, scan_type: :sast, name: 'duplicate-sast', projects: [project])
      end

      let_it_be(:build) do
        create(:ci_build, :success, pipeline: pipeline, project: project, name: 'sast-0',
          options: { artifacts: { reports: { sast: 'gl-sast-report.json' } } }
        ).tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      before do
        allow(::Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore)
          .to receive(:profile_id_for_build).and_return(nil)
      end

      it 'logs a warning and skips fallback resolution' do
        expect(Gitlab::AppLogger).to receive(:warn).with(hash_including(
          message: 'Multiple scan profiles found for scan type, skipping fallback resolution',
          scan_type: :sast,
          project_id: project.id
        ))

        execute
      end

      it_behaves_like 'does not update any status'
    end

    context 'when fallback detects dependency_scanning from cyclonedx report' do
      let_it_be(:ds_profile) do
        create(:security_scan_profile, namespace: group, scan_type: :dependency_scanning, projects: [project])
      end

      let!(:build) do
        create(:ci_build, :success, pipeline: pipeline, project: project, name: 'dependency_scanning-0',
          options: { artifacts: { reports: { cyclonedx: 'gl-sbom.cdx.json' } } }
        ).tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      before do
        allow(::Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore)
          .to receive(:profile_id_for_build).and_return(nil)
      end

      it 'resolves profile ID via dependency_scanning fallback' do
        execute

        status = Security::ScanProfileProjectStatus.find_by(
          project_id: project.id,
          security_scan_profile_id: ds_profile.id
        )

        expect(status).to be_present
        expect(status.status).to eq('success')
      end
    end

    context 'when multiple builds resolve to the same profile' do
      let_it_be(:successful_build) do
        create(:ci_build, :success, pipeline: pipeline, project: project, name: 'sast-0').tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      let_it_be(:failed_build) do
        create(:ci_build, :failed, pipeline: pipeline, project: project, name: 'sast-1').tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      before do
        allow(::Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore)
          .to receive(:profile_id_for_build).and_return(scan_profile.id)
      end

      it 'does not raise PG::CardinalityViolation' do
        expect { execute }.not_to raise_error
      end

      it 'creates exactly one status record per profile' do
        execute

        statuses = Security::ScanProfileProjectStatus.where(
          project_id: project.id,
          security_scan_profile_id: scan_profile.id
        )

        expect(statuses.count).to eq(1)
      end

      it 'keeps the failed build (worst status wins)' do
        execute

        status = Security::ScanProfileProjectStatus.find_by!(
          project_id: project.id,
          security_scan_profile_id: scan_profile.id
        )

        expect(status.status).to eq('warning')
        expect(status.build_id).to eq(failed_build.id)
        expect(status.consecutive_failure_count).to eq(1)
        expect(status.consecutive_success_count).to eq(0)
      end
    end

    context 'when fallback detects scan type but no matching profile exists' do
      let!(:build) do
        create(:ci_build, :success, pipeline: pipeline, project: project, name: 'container-scanning-0',
          options: { artifacts: { reports: { container_scanning: 'gl-container-scanning-report.json' } } }
        ).tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      before do
        allow(::Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore)
          .to receive(:profile_id_for_build).and_return(nil)
      end

      it_behaves_like 'does not update any status'
    end

    context 'when fallback would match a post processing scan type' do
      let(:build) { instance_double(Ci::Build, name: 'post-processing-job', options: build_options) }
      let(:service) { described_class.new(pipeline) }

      let_it_be(:post_processing_profile) do
        create(:security_scan_profile, :dependency_scanning_post_processing, namespace: group, projects: [project])
      end

      context 'when only a post processing report key is present' do
        let(:build_options) do
          { artifacts: { reports: { dependency_scanning_post_processing: 'gl-report.json' } } }
        end

        it 'returns nil from detect_scan_type' do
          expect(service.send(:detect_scan_type, build)).to be_nil
        end
      end

      context 'when both a scanner and a post processing report key are present' do
        let(:build_options) do
          {
            artifacts: {
              reports: {
                sast: 'gl-sast.json',
                dependency_scanning_post_processing: 'gl-report.json'
              }
            }
          }
        end

        it 'returns the scanner key from detect_scan_type' do
          expect(service.send(:detect_scan_type, build)).to eq(:sast)
        end
      end
    end

    context 'when fallback cannot detect scan type' do
      let!(:build) do
        create(:ci_build, :success, pipeline: pipeline, project: project, name: 'unknown-job',
          options: {}
        ).tap do |b|
          create(:ci_build_source, job: b, source: :security_scan_profiles, project_id: project.id)
        end
      end

      before do
        allow(::Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore)
          .to receive(:profile_id_for_build).and_return(nil)
      end

      it_behaves_like 'does not update any status'
    end
  end

  context 'when pipeline has no profile-triggered builds' do
    let!(:build) do
      create(:ci_build, :success, pipeline: pipeline, project: project, name: 'rspec')
    end

    it_behaves_like 'does not update any status'
  end

  context 'when license is not available' do
    before do
      stub_licensed_features(security_scan_profiles: false)
    end

    it_behaves_like 'does not update any status'
  end
end
