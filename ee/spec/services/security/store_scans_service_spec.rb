# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreScansService, feature_category: :vulnerability_management do
  let_it_be_with_reload(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, user: user, project: project) }

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute) { described_class.execute(pipeline) }

    before do
      allow(described_class).to receive(:new).with(pipeline).and_return(mock_service_object)
    end

    it 'delegates the call to an instance of `Security::StoreScansService`' do
      execute

      expect(described_class).to have_received(:new).with(pipeline)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  shared_examples 'does not schedule security reports' do
    it 'does not schedule the `StoreSecurityReportsByProjectWorker`' do
      store_group_of_artifacts

      expect(Security::StoreSecurityReportsByProjectWorker).not_to have_received(:perform_async)
    end
  end

  shared_examples 'does not schedule secret detection' do
    it 'does not schedule ScanSecurityReportSecretsWorker' do
      store_group_of_artifacts

      expect(ScanSecurityReportSecretsWorker).not_to have_received(:perform_async)
    end
  end

  shared_examples 'does not publish Security::ReportsIngestedEvent' do
    it 'does not publish Security::ReportsIngestedEvent' do
      expect(::Gitlab::EventStore).not_to receive(:publish).with(
        an_instance_of(Security::ReportsIngestedEvent)
      )

      store_group_of_artifacts
    end
  end

  shared_examples 'does not schedule token verification' do
    it 'does not schedule GitlabTokenVerificationWorker' do
      store_group_of_artifacts

      expect(Security::SecretDetection::GitlabTokenVerificationWorker).not_to have_received(:perform_async)
    end
  end

  describe '#execute' do
    let(:service_object) { described_class.new(pipeline) }

    let_it_be(:sast_build) { create(:ee_ci_build, pipeline: pipeline, project: project) }
    let_it_be(:dast_build) { create(:ee_ci_build, pipeline: pipeline, project: project) }
    let_it_be(:sast_artifact) { create(:ee_ci_job_artifact, :sast, job: sast_build, project: project) }
    let_it_be(:dast_artifact) { create(:ee_ci_job_artifact, :dast, job: dast_build, project: project) }

    subject(:store_group_of_artifacts) { service_object.execute }

    before do
      allow(Security::StoreSecurityReportsByProjectWorker).to receive(:perform_async)
      allow(ScanSecurityReportSecretsWorker).to receive(:perform_async)
      allow(Security::StoreGroupedScansService).to receive(:execute).and_return(true)
      allow(Security::StoreGroupedSbomScansService).to receive(:execute).and_return(true)
      allow(Security::SecretDetection::GitlabTokenVerificationWorker).to receive(:perform_async)
      stub_licensed_features(sast: true, dast: true, dependency_scanning: true)
    end

    context 'when the pipeline already has a purged security scan' do
      before do
        create(:security_scan, status: :purged, build: sast_build)
      end

      it 'does not store the security scans' do
        store_group_of_artifacts

        expect(Security::StoreGroupedScansService).not_to have_received(:execute)
      end
    end

    it 'stores scans using the proper service' do
      store_group_of_artifacts

      expect(Security::StoreGroupedScansService).to have_received(:execute).with([sast_artifact], pipeline, 'sast')
      expect(Security::StoreGroupedScansService).to have_received(:execute).with([dast_artifact], pipeline, 'dast')
    end

    context 'when license feature is not available' do
      before do
        stub_licensed_features(sast: false, dast: false, dependency_scanning: false)
      end

      it 'does not store scans' do
        store_group_of_artifacts

        expect(Security::StoreGroupedScansService).not_to have_received(:execute)
          .with([sast_artifact], pipeline, 'sast')
        expect(Security::StoreGroupedScansService).not_to have_received(:execute)
          .with([dast_artifact], pipeline, 'dast')
      end
    end

    context 'when there is a dependency scanning SBoM' do
      let_it_be(:cyclonedx_build) { create(:ee_ci_build, :success, pipeline: pipeline, project: project) }
      let_it_be(:cyclonedx_artifact) { create(:ee_ci_job_artifact, :cyclonedx, job: cyclonedx_build) }

      it 'stores the sbom scans' do
        store_group_of_artifacts

        expect(Security::StoreGroupedSbomScansService).to have_received(:execute)
          .with([cyclonedx_artifact], pipeline, 'dependency_scanning')
      end
    end

    context 'with cyclonedx from a container scanning job' do
      let_it_be(:cyclonedx_cs_build) { create(:ee_ci_build, pipeline: pipeline) }
      let_it_be(:cyclonedx_cs_artifact) do
        create(:ee_ci_job_artifact, :cyclonedx_container_scanning, job: cyclonedx_cs_build)
      end

      it 'does not execute container scanning cyclonedx artifact' do
        store_group_of_artifacts

        expect(Security::StoreGroupedSbomScansService).not_to have_received(:execute)
          .with([cyclonedx_cs_artifact], pipeline, 'container_scanning')
      end
    end

    describe 'storing security reports' do
      context 'when the pipeline is for the default branch' do
        let(:project_id) { pipeline.project.id }
        let(:cache_key) { Security::StoreSecurityReportsByProjectWorker.cache_key(project_id: project_id) }

        before do
          allow(pipeline).to receive(:default_branch?).and_return(true)
        end

        it 'schedules the `StoreSecurityReportsByProjectWorker`' do
          store_group_of_artifacts

          expect(Security::StoreSecurityReportsByProjectWorker).to have_received(:perform_async).with(
            project_id
          )
        end

        it 'sets the expected redis cache value', :clean_gitlab_redis_shared_state do
          expect { store_group_of_artifacts }.to change {
            Gitlab::Redis::SharedState.with { |redis| redis.get(cache_key) }
          }.from(nil).to(pipeline.id.to_s)
        end
      end

      context 'when the pipeline is not for the default branch' do
        before do
          allow(pipeline).to receive(:default_branch?).and_return(false)
        end

        it_behaves_like 'does not schedule security reports'
      end
    end

    describe 'secret detection scheduling' do
      before do
        pipeline.project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)

        allow(Gitlab::CurrentSettings).to receive(
          :secret_detection_token_revocation_enabled?).and_return(true)
      end

      context 'when there are no secret detection scans' do
        it_behaves_like 'does not schedule secret detection'
      end

      context 'when there are secret detection scans' do
        let_it_be(:scan) { create(:security_scan, scan_type: :secret_detection, build: sast_build) }
        let_it_be(:finding) do
          create(:security_finding, scan: scan, scanner: create(:vulnerabilities_scanner, project: project))
        end

        it 'schedules secret detection' do
          store_group_of_artifacts

          expect(ScanSecurityReportSecretsWorker).to have_received(:perform_async).with(pipeline.id)
        end

        context 'when project is not public' do
          before do
            pipeline.project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)
          end

          it_behaves_like 'does not schedule secret detection'
        end

        context 'when application setting is disabled' do
          before do
            allow(Gitlab::CurrentSettings).to receive(
              :secret_detection_token_revocation_enabled?).and_return(false)
          end

          it_behaves_like 'does not schedule secret detection'
        end
      end
    end

    describe 'token verification scheduling' do
      before do
        allow(pipeline).to receive(:default_branch?).and_return(false)
        pipeline.project.security_setting.update!(validity_checks_enabled: true)
      end

      context 'when there are no secret detection scans' do
        it_behaves_like 'does not schedule token verification'
      end

      context 'when there are secret detection scans' do
        let_it_be(:scan) { create(:security_scan, scan_type: :secret_detection, build: sast_build) }
        let_it_be(:finding) do
          create(:security_finding, scan: scan, scanner: create(:vulnerabilities_scanner, project: project))
        end

        it 'schedules token verification' do
          store_group_of_artifacts

          expect(Security::SecretDetection::GitlabTokenVerificationWorker).to have_received(:perform_async)
            .with(pipeline.id)
        end

        context 'when pipeline is on the default branch' do
          before do
            allow(pipeline).to receive(:default_branch?).and_return(true)
          end

          it_behaves_like 'does not schedule token verification'
        end

        context 'when validity checks setting is disabled' do
          before do
            pipeline.project.security_setting.update!(validity_checks_enabled: false)
          end

          it_behaves_like 'does not schedule token verification'
        end
      end
    end

    context 'when no scans were stored' do
      before do
        allow(Security::StoreGroupedScansService).to receive(:execute).and_return(false)
        allow(Security::StoreGroupedSbomScansService).to receive(:execute).and_return(false)
      end

      context 'and the pipeline is for the default branch' do
        before do
          allow(pipeline).to receive(:default_branch?).and_return(true)
        end

        it 'still schedules the `StoreSecurityReportsByProjectWorker`' do
          store_group_of_artifacts

          expect(Security::StoreSecurityReportsByProjectWorker).to have_received(:perform_async).with(
            pipeline.project.id
          )
        end
      end

      context 'and secret detection would be scheduled' do
        let_it_be(:scan) { create(:security_scan, scan_type: :secret_detection, build: sast_build) }
        let_it_be(:finding) do
          create(:security_finding, scan: scan, scanner: create(:vulnerabilities_scanner, project: project))
        end

        before do
          pipeline.project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
          allow(Gitlab::CurrentSettings).to receive(
            :secret_detection_token_revocation_enabled?).and_return(true)
        end

        it 'still schedules secret detection' do
          store_group_of_artifacts

          expect(ScanSecurityReportSecretsWorker).to have_received(:perform_async).with(pipeline.id)
        end
      end

      context 'and token verification would be scheduled' do
        let_it_be(:scan) { create(:security_scan, scan_type: :secret_detection, build: sast_build) }
        let_it_be(:finding) do
          create(:security_finding, scan: scan, scanner: create(:vulnerabilities_scanner, project: project))
        end

        before do
          allow(pipeline).to receive(:default_branch?).and_return(false)
          pipeline.project.security_setting.update!(validity_checks_enabled: true)
        end

        it 'still schedules token verification' do
          store_group_of_artifacts

          expect(Security::SecretDetection::GitlabTokenVerificationWorker).to have_received(:perform_async)
            .with(pipeline.id)
        end
      end
    end

    context 'with cyclonedx and dependency scanning artifacts related to the same job' do
      let_it_be(:pipeline) { create(:ci_pipeline, ref: project.default_branch, user: user, project: project) }
      let_it_be(:build) { create(:ee_ci_build, :success, pipeline: pipeline, project: project) }
      let_it_be(:cyclonedx_artifact) { create(:ee_ci_job_artifact, :cyclonedx, job: build) }
      let_it_be(:dependency_scanning_artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: build) }
      let_it_be(:cyclonedx_findings_count) { 1 }
      let_it_be(:ds_findings_count) { 4 }
      let_it_be(:affected_package) do
        create(:pm_affected_package, purl_type: :npm, package_name: 'yargs-parser', affected_range: "<9.1")
      end

      let_it_be(:security_report) { dependency_scanning_artifact.security_report }

      before do
        allow(Security::StoreGroupedScansService).to receive(:execute).and_call_original
        allow(Security::StoreGroupedSbomScansService).to receive(:execute).and_call_original
      end

      it 'skips the cyclonedx artifact and only processes the dependency_scanning artifact' do
        store_group_of_artifacts

        expect(Security::StoreGroupedSbomScansService).not_to have_received(:execute)
          .with([cyclonedx_artifact], pipeline, 'dependency_scanning')
        expect(Security::StoreGroupedScansService).to have_received(:execute)
          .with([dependency_scanning_artifact], pipeline, 'dependency_scanning')
      end

      context 'with different artifacts with findings with similar uuid' do
        before do
          # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
          allow_any_instance_of(EE::Ci::JobArtifact).to receive(:security_report).and_return(security_report)
          # rubocop:enable RSpec/AnyInstanceOf
        end

        it 'does not created cyclonedx related findings' do
          expect { store_group_of_artifacts }.to change { Security::Finding.count }.by(ds_findings_count)
        end
      end
    end

    context 'with different jobs with the same cyclonedx related findings' do
      let_it_be(:build) { create(:ee_ci_build, :success, pipeline: pipeline, project: project) }
      let_it_be(:cyclonedx_artifact) { create(:ee_ci_job_artifact, :cyclonedx, job: build) }
      let_it_be(:cyclonedx_findings_count) { 1 }
      let_it_be(:affected_package) do
        create(:pm_affected_package, purl_type: :npm, package_name: 'yargs-parser', affected_range: "<9.1")
      end

      before do
        allow(Security::StoreGroupedScansService).to receive(:execute).and_call_original
        allow(Security::StoreGroupedSbomScansService).to receive(:execute).and_call_original
      end

      it 'creates only unique security findings' do
        expect { store_group_of_artifacts }.to change {
          Security::Finding.deduplicated.count
        }.by(cyclonedx_findings_count)
      end
    end

    it 'publishes Security::ReportsIngestedEvent' do
      expect(::Gitlab::EventStore).to receive(:publish).with(
        an_instance_of(Security::ReportsIngestedEvent).and(
          having_attributes(data: { pipeline_id: pipeline.id })
        )
      )

      store_group_of_artifacts
    end

    context 'when the pipeline has purged security scans' do
      before do
        create(:security_scan, status: :purged, build: sast_build)
      end

      it_behaves_like 'does not publish Security::ReportsIngestedEvent'
    end

    context 'when storing scans raises an error' do
      before do
        allow(Security::StoreGroupedScansService).to receive(:execute).and_raise(StandardError)
      end

      it 'does not publish Security::ReportsIngestedEvent' do
        expect(::Gitlab::EventStore).not_to receive(:publish).with(
          an_instance_of(Security::ReportsIngestedEvent)
        )

        expect { store_group_of_artifacts }.to raise_error(StandardError)
      end
    end
  end
end
