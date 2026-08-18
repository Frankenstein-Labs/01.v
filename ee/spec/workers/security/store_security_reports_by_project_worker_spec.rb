# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreSecurityReportsByProjectWorker, feature_category: :vulnerability_management do
  let_it_be(:group)   { create(:group) }
  let_it_be(:project) { create(:project, :pipeline_refs, namespace: group) }
  let_it_be(:tracked_context) do
    create(:security_project_tracked_context, :default, project: project, context_name: project.default_branch)
  end

  let(:pipeline) do
    create(
      :ee_ci_pipeline,
      :with_sast_report,
      status: :success,
      ref: project.default_branch,
      project: project,
      user: project.creator
    )
  end

  let(:scan_object) do
    ::Gitlab::Ci::Reports::Security::Scan.new(
      {
        "type" => :sast,
        "start_time" => "20241022T11:56:41",
        "end_time" => "20241022T11:57:39",
        "status" => "success"
      })
  end

  describe '.cache_key' do
    subject { described_class.cache_key(project_id: project.id) }

    it { is_expected.to eq("#{described_class}::latest_pipeline_with_security_reports::#{project.id}") }

    context 'when project_id is nil' do
      it 'returns nil' do
        expect(described_class.cache_key(project_id: nil)).to be_nil
      end
    end

    context 'when project_id is not present' do
      it 'returns nil' do
        expect(described_class.cache_key(project_id: '')).to be_nil
      end
    end
  end

  describe '#perform' do
    subject(:perform) { worker.perform(project_id) }

    let(:worker) { described_class.new }

    context 'when there is no project with the given ID' do
      let(:project_id) { non_existing_record_id }

      it 'does not raise an error' do
        expect { perform }.not_to raise_error
      end
    end

    context 'when there is no pipeline associated to the project' do
      let(:project_id) { project.id }

      before do
        stub_licensed_features(sast: true)
      end

      it 'does not raise an error' do
        expect { perform }.not_to raise_error
      end
    end

    context "when the security reports feature is not available" do
      where(report_type: Enums::Ci::JobArtifact.security_report_file_types.map(&:to_sym))
      with_them do
        before do
          stub_licensed_features(report_type => false)
        end

        it 'does not execute IngestReportsService' do
          expect(::Security::Ingestion::IngestReportsService).not_to receive(:execute)

          worker.perform(project.id)
        end
      end
    end

    context 'when at least one security report feature is enabled' do
      where(report_type: Enums::Ci::JobArtifact.security_report_file_types.map(&:to_sym))

      with_them do
        before do
          stub_licensed_features(report_type => true)
          update_cache(pipeline)
        end

        it 'executes IngestReportsService for given pipeline' do
          expect(::Security::Ingestion::IngestReportsService).to receive(:execute).with(pipeline)

          worker.perform(project.id)
        end
      end
    end

    context 'when running SAST analyzers that produce duplicate vulnerabilities' do
      let(:pipeline2) do
        create(
          :ee_ci_pipeline,
          :with_sast_report,
          status: :success,
          ref: 'master',
          project: project,
          user: project.creator,
          pipeline_metadata: create(:ci_pipeline_metadata, project: project)
        )
      end

      where(vulnerability_finding_signatures_enabled: [true, false])
      with_them do
        before do
          stub_licensed_features(
            sast: true,
            vulnerability_finding_signatures: vulnerability_finding_signatures_enabled
          )
          update_cache(pipeline)
        end

        context 'and prefers original analyzer over semgrep when deduplicating' do
          let(:artifact_bandit1) do
            create(
              :ci_build, :sast, :success,
              user: project.creator, pipeline: pipeline, project: project
            ).then { |build| create(:ee_ci_job_artifact, :sast_bandit, job: build) }
          end

          let(:artifact_bandit2) do
            create(
              :ci_build, :sast, :success,
              user: project.creator, pipeline: pipeline2, project: project
            ).then { |build| create(:ee_ci_job_artifact, :sast_bandit, job: build) }
          end

          let(:artifact_semgrep) do
            create(
              :ci_build, :sast, :success,
              user: project.creator, pipeline: pipeline2, project: project
            ).then { |build| create(:ee_ci_job_artifact, :sast_semgrep_for_bandit, job: build) }
          end

          it 'does not duplicate vulnerabilities' do
            # seeding a scan that should be ingested as a vulnerability
            allow(artifact_bandit1.security_report).to receive(:scan).and_return(scan_object)
            Security::StoreGroupedScansService.execute([artifact_bandit1], pipeline, 'sast')
            expect(Security::Finding.count).to eq 1
            expect(Security::Scan.count).to eq 1

            # ingest the security finding/scan into a
            # vulnerability/vulnerability_finding
            expect { worker.perform(project.id) }.to change {
              Vulnerabilities::Finding.count
            }.from(0).to(1).and change { Vulnerability.count }.from(0).to(1)

            # seeding a scan that is indicating the same vulnerability
            # we just ingested
            allow(artifact_bandit2.security_report).to receive(:scan).and_return(scan_object)
            allow(artifact_semgrep.security_report).to receive(:scan).and_return(scan_object)
            Security::StoreGroupedScansService.execute([artifact_bandit2, artifact_semgrep], pipeline2, 'sast')
            expect(Security::Finding.count).to eq 3
            expect(Security::Scan.count).to eq 3

            # simulate a new pipeline completing
            update_cache(pipeline2)

            # After running the worker again, we do not create
            # additional vulnerabiities (since they would be duplicates)
            expect { worker.perform(project.id) }
              .to not_change { Vulnerabilities::Finding.count }
              .and not_change { Vulnerability.count }
          end
        end

        context 'and prefers semgrep over original analyzer when deduplicating' do
          let(:artifact_gosec1) do
            create(
              :ci_build, :sast, :success,
              user: project.creator, pipeline: pipeline, project: project
            ).then { |build| create(:ee_ci_job_artifact, :sast_gosec, job: build) }
          end

          let(:artifact_gosec2) do
            create(
              :ci_build, :sast, :success,
              user: project.creator, pipeline: pipeline2, project: project
            ).then { |build| create(:ee_ci_job_artifact, :sast_gosec, job: build) }
          end

          let(:artifact_semgrep) do
            create(
              :ci_build, :sast, :success,
              user: project.creator, pipeline: pipeline2, project: project
            ).then { |build| create(:ee_ci_job_artifact, :sast_semgrep_for_gosec, job: build) }
          end

          it 'does not duplicate vulnerabilities' do
            # seeding a scan that should be ingested as a vulnerability
            allow(artifact_gosec1.security_report).to receive(:scan).and_return(scan_object)
            Security::StoreGroupedScansService.execute([artifact_gosec1], pipeline, 'sast')
            expect(Security::Finding.count).to eq 1
            expect(Security::Scan.count).to eq 1

            # ingest the security finding/scan into a
            # vulnerability/vulnerability_finding
            expect { worker.perform(project.id) }.to change {
              Vulnerabilities::Finding.count
            }.from(0).to(1).and change { Vulnerability.count }.from(0).to(1)

            # seeding a scan that is indicating the same vulnerability
            # we just ingested
            allow(artifact_gosec2.security_report).to receive(:scan).and_return(scan_object)
            allow(artifact_semgrep.security_report).to receive(:scan).and_return(scan_object)
            Security::StoreGroupedScansService.execute([artifact_gosec2, artifact_semgrep], pipeline2, 'sast')
            expect(Security::Finding.count).to eq 3
            expect(Security::Scan.count).to eq 3

            # simulate a new pipeline completing
            update_cache(pipeline2)

            # After running the worker again, we do not create
            # additional vulnerabiities (since they would be duplicates)
            expect { worker.perform(project.id) }
              .to not_change { Vulnerabilities::Finding.count }
              .and not_change { Vulnerability.count }
          end
        end
      end
    end

    context 'when resolving dropped identifiers', :sidekiq_inline do
      let(:artifact_semgrep1) { create(:ee_ci_job_artifact, :sast_semgrep_for_multiple_findings, job: semgrep1_build) }

      let(:semgrep1_build) do
        create(:ci_build, :sast, :success, user: project.creator, pipeline: pipeline, project: project)
      end

      let(:pipeline2) do
        create(
          :ee_ci_pipeline,
          :with_sast_report,
          status: :success,
          ref: 'master',
          project: project,
          user: project.creator
        )
      end

      let(:artifact_semgrep2) { create(:ee_ci_job_artifact, :sast_semgrep_for_gosec, job: semgrep2_build) }
      let(:semgrep2_build) do
        create(:ci_build, :sast, :success, user: project.creator, pipeline: pipeline2, project: project)
      end

      before do
        stub_licensed_features(sast: true)
        update_cache(pipeline)
      end

      it 'resolves vulnerabilities' do
        allow(artifact_semgrep1.security_report).to receive(:scan).and_return(scan_object)
        allow(::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker).to receive(:perform_async)

        expect do
          Security::StoreGroupedScansService.execute([artifact_semgrep1], pipeline, 'sast')
        end.to change { Security::Finding.count }.by(2)
           .and change { Security::Scan.count }.by(1)

        expect do
          worker.perform(project.id)
        end.to change { Vulnerabilities::Finding.count }.by(2)
           .and change { Vulnerability.count }.by(2)
           .and change { project.vulnerabilities.with_resolution(false).count }.by(2)
           .and change { project.vulnerabilities.with_states(%w[detected]).count }.by(2)

        allow(artifact_semgrep2.security_report).to receive(:scan).and_return(scan_object)
        expect do
          Security::StoreGroupedScansService.execute([artifact_semgrep2], pipeline2, 'sast')
        end.to change { Security::Finding.count }.by(1)
           .and change { Security::Scan.count }.by(1)

        # simulate a new pipeline completing
        update_cache(pipeline2)

        expect do
          worker.perform(project.id)
        end.to not_change { Vulnerabilities::Finding.count }
           .and not_change { Vulnerability.count }
           .and change { project.vulnerabilities.with_resolution(true).count }.by(1)
           .and change { project.vulnerabilities.with_states(%w[detected]).count }.by(-1)
           .and change { project.vulnerabilities.with_states(%w[resolved]).count }.by(1)
      end
    end

    context "when the same scanner runs multiple times in one pipeline" do
      let(:artifact_sast1) do
        create(
          :ci_build, :sast, :success,
          user: project.creator, pipeline: pipeline, project: project
        ).then { |build| create(:ee_ci_job_artifact, :semgrep_web_vulnerabilities, job: build) }
      end

      let(:artifact_sast2) do
        create(
          :ci_build, :sast, :success,
          user: project.creator, pipeline: pipeline, project: project
        ).then { |build| create(:ee_ci_job_artifact, :semgrep_api_vulnerabilities, job: build) }
      end

      before do
        stub_licensed_features(sast: true)
        update_cache(pipeline)
      end

      it "does not mark any of the detected vulnerabilities as resolved",
        :aggregate_failures do
        allow(artifact_sast2.security_report).to receive(:scan).and_return(scan_object)
        Security::StoreGroupedScansService.execute([artifact_sast2], pipeline, 'sast')
        expect(Security::Finding.count).to eq 1
        expect(Security::Scan.count).to eq 1

        allow(artifact_sast1.security_report).to receive(:scan).and_return(scan_object)
        Security::StoreGroupedScansService.execute([artifact_sast1], pipeline, 'sast')
        expect(Security::Finding.count).to eq 2
        expect(Security::Scan.count).to eq 2

        expect { worker.perform(project.id) }.to change { Vulnerability.count }.by(2)
        expect(project.vulnerabilities.map(&:resolved_on_default_branch)).not_to include(true)
      end
    end
  end

  def update_cache(pipeline)
    cache_key = described_class.cache_key(project_id: pipeline.project_id)
    Gitlab::Redis::SharedState.with { |redis| redis.set(cache_key, pipeline.id) }
  end
end
