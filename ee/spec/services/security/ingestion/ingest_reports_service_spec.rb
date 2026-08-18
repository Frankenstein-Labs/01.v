# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- This test requires various records to be created for proper setup
RSpec.describe Security::Ingestion::IngestReportsService, feature_category: :vulnerability_management do
  let(:service_object) { described_class.new(pipeline) }

  let_it_be_with_refind(:project) { create(:project, :repository) }
  let_it_be_with_refind(:pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch) }
  let_it_be(:tracked_context) { create(:security_project_tracked_context, :default, :tracked, project: project) }
  let_it_be(:build) { create(:ci_build, pipeline: pipeline) }
  let_it_be(:security_scan_1) { create(:security_scan, build: build, scan_type: :sast) }
  let_it_be(:security_scan_2) { create(:security_scan, build: build, scan_type: :dependency_scanning) }
  let_it_be(:security_scan_3) { create(:security_scan, build: build, scan_type: :container_scanning) }
  let_it_be(:security_scan_4) { create(:security_scan, :with_error, build: build, scan_type: :dast) }
  let_it_be(:sast_scanner) { create(:vulnerabilities_scanner, :sast_scanner, project: project) }
  let_it_be(:sbom_scanner) { create(:vulnerabilities_scanner, :sbom_scanner, project: project) }
  let_it_be(:cs_scanner) { create(:vulnerabilities_scanner, :cs_scanner, project: project) }
  let_it_be(:dast_scanner) { create(:vulnerabilities_scanner, :dast_scanner, project: project) }
  let_it_be(:vulnerability_1) { create(:vulnerability, :with_scanner, scanner: sast_scanner, project: pipeline.project) }
  let_it_be(:vulnerability_2) { create(:vulnerability, :with_scanner, scanner: sbom_scanner, project: pipeline.project) }
  let_it_be(:sast_artifact) { create(:ee_ci_job_artifact, :sast, job: build, project: project) }
  let_it_be(:ds_artifact) { create(:ee_ci_job_artifact, :dependency_scanning_with_new_DS_analyzer, job: build, project: project) }
  let_it_be(:cs_artifact) { create(:ee_ci_job_artifact, :container_scanning, job: build, project: project) }
  let_it_be(:dast_artifact) { create(:ee_ci_job_artifact, :dast, job: build, project: project) }

  describe '#execute' do
    let(:ids_1) { [vulnerability_1.id] }
    let(:ids_2) { [vulnerability_2.id] }
    let(:ids_3) { [] }

    subject(:ingest_reports) { service_object.execute }

    before do
      allow(Security::Ingestion::IngestReportService).to receive(:execute).and_return(ids_1, ids_2, ids_3)
      allow(Security::Ingestion::ScheduleMarkDroppedAsResolvedService).to receive(:execute)
      allow(Sbom::IngestReportsWorker).to receive(:perform_async)
      allow(::Security::ProjectTrackedContexts::FindOrCreateService).to receive(:from_pipeline)
        .and_return(instance_double(
          ::Security::ProjectTrackedContexts::FindOrCreateService,
          execute: ServiceResponse.success(payload: { tracked_context: tracked_context })
        ))
    end

    it 'calls IngestReportService for each valid security scan', :aggregate_failures do
      ingest_reports

      expect(Security::Ingestion::IngestReportService).to have_received(:execute).exactly(3).times
      expect(Security::Ingestion::IngestReportService).to have_received(:execute).once.with(security_scan_1)
      expect(Security::Ingestion::IngestReportService).to have_received(:execute).once.with(security_scan_2)
      expect(Security::Ingestion::IngestReportService).to have_received(:execute).once.with(security_scan_3)
    end

    it_behaves_like 'schedules synchronization of vulnerability statistic' do
      let(:latest_pipeline) { pipeline }
    end

    context 'when ingested reports are empty' do
      let(:ids_1) { [] }
      let(:ids_2) { [] }

      before do
        project.vulnerabilities.delete_all
      end

      it 'does not set has_vulnerabilities' do
        expect { ingest_reports }.not_to change { project.reload.project_setting.has_vulnerabilities }.from(false)
      end
    end

    it 'calls ScheduleMarkDroppedAsResolvedService with primary identifier IDs' do
      ingest_reports

      expect(
        Security::Ingestion::ScheduleMarkDroppedAsResolvedService
      ).to have_received(:execute).with(project.id, 'sast', sast_artifact.security_report.primary_identifiers)
    end

    it 'calls MarkAsResolvedService for each scanner and scan type', :aggregate_failures do
      expect(Security::Ingestion::MarkAsResolvedService).to receive(:execute).once.with(pipeline, sast_scanner, ids_1, tracked_context, 'sast')
      expect(Security::Ingestion::MarkAsResolvedService).to receive(:execute).once.with(pipeline, sbom_scanner, ids_2, tracked_context, 'dependency_scanning')
      expect(Security::Ingestion::MarkAsResolvedService).to receive(:execute).once.with(pipeline, cs_scanner, ids_3, tracked_context, 'container_scanning')

      ingest_reports
    end

    context 'when the same scanner is used into separate child pipelines' do
      let_it_be(:parent_pipeline) { create(:ee_ci_pipeline, :success, project: project) }
      let_it_be(:child_pipeline_1) { create(:ee_ci_pipeline, :success, child_of: parent_pipeline, project: project) }
      let_it_be(:child_pipeline_2) { create(:ee_ci_pipeline, :success, child_of: parent_pipeline, project: project) }
      let_it_be(:parent_build) { create(:ci_build, pipeline: parent_pipeline) }
      let_it_be(:parent_scan) { create(:security_scan, build: parent_build, scan_type: :sast) }
      let_it_be(:scan_1) { create(:security_scan, pipeline: child_pipeline_1, project: project, scan_type: :sast) }
      let_it_be(:scan_2) { create(:security_scan, pipeline: child_pipeline_2, project: project, scan_type: :sast) }
      let_it_be(:parent_artifact) { create(:ee_ci_job_artifact, :sast, job: parent_scan.build, project: project) }
      let_it_be(:artifact_sast_1) { create(:ee_ci_job_artifact, :sast, job: scan_1.build, project: project) }
      let_it_be(:artifact_sast_2) { create(:ee_ci_job_artifact, :sast, job: scan_2.build, project: project) }

      subject(:service_object) { described_class.new(parent_pipeline) }

      it 'ingests the scan from both child pipelines', :aggregate_failures do
        service_object.execute

        expect(Security::Ingestion::IngestReportService).to have_received(:execute).with(parent_scan)
        expect(Security::Ingestion::IngestReportService).to have_received(:execute).with(scan_1)
        expect(Security::Ingestion::IngestReportService).to have_received(:execute).with(scan_2)
      end
    end

    it_behaves_like 'schedules synchronization of findings to approval rules' do
      let(:latest_pipeline) { pipeline }
    end

    context 'when scheduling the SBOM ingestion' do
      let(:sbom_ingestion_scheduler) { instance_double(::Sbom::ScheduleIngestReportsService, execute: nil) }

      before do
        allow(::Sbom::ScheduleIngestReportsService).to receive(:new).with(pipeline).and_return(sbom_ingestion_scheduler)
      end

      it 'defers to ScheduleIngestReportsService', :aggregate_failures do
        ingest_reports

        expect(::Sbom::ScheduleIngestReportsService).to have_received(:new).with(pipeline)
        expect(sbom_ingestion_scheduler).to have_received(:execute)
      end
    end

    it_behaves_like 'rescheduling archival status and traversal_ids update jobs' do
      let(:job_args) { project.id }
      let(:scheduling_method) { :perform_async }
      let(:ingest_vulnerabilities) { ingest_reports }
      let(:update_archived_after_start) do
        allow(service_object).to receive(:store_reports).and_wrap_original do |method|
          project.update_column(:archived, true)

          method.call
        end
      end

      let(:update_traversal_ids_after_start) do
        allow(service_object).to receive(:store_reports).and_wrap_original do |method|
          project.namespace.update_column(:traversal_ids, [-1])

          method.call
        end
      end

      let(:update_namespace_after_start) do
        allow(service_object).to receive(:store_reports).and_wrap_original do |method|
          project.update_column(:namespace_id, new_namespace.id)

          method.call
        end
      end
    end

    describe 'ingestion telemetry', :clean_gitlab_redis_shared_state do
      it 'logs the ingestion for the default branch' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(
            'class_name' => described_class.name,
            'message' => 'Ingesting security reports',
            'gl_project_id' => project.id,
            'gl_pipeline_id' => pipeline.id,
            'context_name' => project.default_branch,
            'context_type' => 'branch',
            'is_default' => true
          )
        )

        ingest_reports
      end

      it 'tracks the ingestion as being for the default branch' do
        expect { ingest_reports }
          .to trigger_internal_events('ingest_security_reports')
          .with(project: project, namespace: project.namespace, additional_properties: { label: 'default_branch' })
          .and increment_usage_metrics(
            'redis_hll_counters.count_distinct_project_id_from_ingest_security_reports_monthly',
            'redis_hll_counters.count_distinct_project_id_from_ingest_security_reports_for_default_branch_monthly'
          )
      end

      it 'does not count the ingestion as being for a non-default branch' do
        expect { ingest_reports }.not_to increment_usage_metrics(
          'redis_hll_counters.count_distinct_project_id_from_ingest_security_reports_for_non_default_branches_monthly'
        )
      end

      context 'when the reports are ingested for a non-default tracked context' do
        let_it_be(:non_default_pipeline) { create(:ci_pipeline, project: project, ref: 'feature') }
        let_it_be(:non_default_context) do
          create(:security_project_tracked_context, :tracked, project: project, context_name: 'feature')
        end

        let(:service_object) { described_class.new(non_default_pipeline) }

        before do
          allow(::Security::ProjectTrackedContexts::FindOrCreateService).to receive(:from_pipeline)
            .and_return(instance_double(
              ::Security::ProjectTrackedContexts::FindOrCreateService,
              execute: ServiceResponse.success(payload: { tracked_context: non_default_context })
            ))
        end

        it 'logs the ingestion for the non-default context' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              'class_name' => described_class.name,
              'message' => 'Ingesting security reports',
              'gl_project_id' => project.id,
              'gl_pipeline_id' => non_default_pipeline.id,
              'context_name' => 'feature',
              'context_type' => 'branch',
              'is_default' => false
            )
          )

          ingest_reports
        end

        it 'tracks the ingestion as being for a non-default branch' do
          expect { ingest_reports }
            .to trigger_internal_events('ingest_security_reports')
            .with(
              project: project,
              namespace: project.namespace,
              additional_properties: { label: 'non_default_branch' }
            )
            .and increment_usage_metrics(
              'redis_hll_counters.count_distinct_project_id_from_ingest_security_reports_monthly',
              'redis_hll_counters.count_distinct_project_id_from_ingest_security_reports_for_non_default_branches_monthly'
            )
        end

        it 'does not count the ingestion as being for the default branch' do
          expect { ingest_reports }.not_to increment_usage_metrics(
            'redis_hll_counters.count_distinct_project_id_from_ingest_security_reports_for_default_branch_monthly'
          )
        end
      end
    end

    describe 'vulnerability policy auto-dismissal' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
        allow(Ability).to receive(:allowed?).with(bot_user, :create_vulnerability_state_transition, project).and_return(true)
      end

      let_it_be(:vulnerability_3) do
        create(:vulnerability, :with_scanner, scanner: sast_scanner, project: pipeline.project).tap do |vuln|
          vuln.findings.first.identifiers.first.update!(name: 'CVE-2020-4567')
        end
      end

      let(:ids_1) { [vulnerability_1.id, vulnerability_3.id] }

      let_it_be(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      let!(:policy) do
        create(:security_policy, :vulnerability_management_policy,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          content: policy_content,
          linked_projects: [project])
      end

      let!(:policy_rule) do
        create(:vulnerability_management_policy_rule, :detected, security_policy: policy, content: rule_content)
      end

      let(:policy_content) do
        {
          'actions' => [
            {
              'type' => 'auto_dismiss',
              'dismissal_reason' => 'acceptable_risk'
            }
          ]
        }
      end

      let(:cve_identifier) { vulnerability_3.finding.identifiers.first.name }
      let(:rule_content) do
        {
          'criteria' => [
            {
              'type' => 'identifier',
              'value' => cve_identifier
            }
          ]
        }
      end

      let_it_be(:bot_user) { create(:user, :security_policy_bot, guest_of: project) }

      it 'automatically dismisses the vulnerabilities in the given project based on criteria', :aggregate_failures do
        expect(Gitlab::AppJsonLogger).to receive(:debug).with(
          message: "Auto-dismissed vulnerabilities",
          project_id: project.id,
          pipeline_id: pipeline.id,
          scanner: sast_scanner,
          count: 1
        )
        expect { ingest_reports }.to change { vulnerability_3.reload.state }.from('detected').to('dismissed')
          .and not_change { vulnerability_1.reload.state }.from('detected')
      end

      shared_examples_for 'does not dismiss the vulnerabilities' do
        it 'does not dismiss the vulnerabilities' do
          ingest_reports

          expect(project.vulnerabilities).to all be_detected
        end
      end

      context 'when no vulnerabilities need to be dismissed' do
        before do
          policy_rule.update!(content: { 'criteria' => [{ 'type' => 'identifier', 'value' => 'CVE-222222' }] })
        end

        it 'does not log any message' do
          expect(Gitlab::AppJsonLogger).not_to receive(:debug)

          ingest_reports
        end

        it_behaves_like 'does not dismiss the vulnerabilities'
      end

      context 'when auto-dismissal fails' do
        before do
          allow_next_instance_of(Vulnerabilities::AutoDismissService) do |instance|
            allow(instance).to receive(:execute).and_return(ServiceResponse.error(
              message: 'Could not dismiss vulnerabilities',
              reason: 'something failed'
            ))
          end
        end

        it 'logs an error message for each processed scan', :aggregate_failures do
          expect(Gitlab::AppJsonLogger).to receive(:error).once.with(
            message: "Failed to auto-dismiss vulnerabilities",
            project_id: project.id,
            pipeline_id: pipeline.id,
            scanner: sast_scanner,
            error: "Could not dismiss vulnerabilities",
            reason: 'something failed'
          )

          expect(Gitlab::AppJsonLogger).to receive(:error).once.with(
            message: "Failed to auto-dismiss vulnerabilities",
            project_id: project.id,
            pipeline_id: pipeline.id,
            scanner: sbom_scanner,
            error: "Could not dismiss vulnerabilities",
            reason: 'something failed'
          )

          ingest_reports

          expect(project.vulnerabilities).to all be_detected
        end
      end

      context 'when unexpected exception occurs' do
        before do
          allow_next_instance_of(Vulnerabilities::AutoDismissService) do |instance|
            allow(instance).to receive(:execute).and_raise('something failed')
          end
        end

        it 'logs an error message', :aggregate_failures do
          expect(Gitlab::AppJsonLogger).to receive(:error).with(
            message: "Exception during auto-dismiss vulnerabilities",
            project_id: project.id,
            pipeline_id: pipeline.id,
            error: 'something failed'
          )
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(StandardError)

          ingest_reports
        end
      end

      context 'when criteria do not match' do
        let(:rule_content) do
          {
            'criteria' => [
              {
                'type' => 'identifier',
                'value' => 'CVE-12345'
              }
            ]
          }
        end

        it_behaves_like 'does not dismiss the vulnerabilities'
      end

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it_behaves_like 'does not dismiss the vulnerabilities'
      end
    end

    describe 'vulnerability policy auto-severity-override' do
      let(:auto_override_result) { ServiceResponse.success(payload: { count: 1 }) }
      let(:auto_override_service) { instance_double(Vulnerabilities::AutoSeverityOverrideService) }

      before do
        allow(Vulnerabilities::AutoSeverityOverrideService).to receive(:new)
          .and_return(auto_override_service)
        allow(auto_override_service).to receive(:execute).and_return(auto_override_result)
      end

      it 'runs after auto-dismiss vulnerabilities' do
        call_order = []
        allow(service_object).to receive(:auto_dismiss_vulnerabilities).and_wrap_original do |original|
          call_order << :auto_dismiss
          original.call
        end
        allow(auto_override_service).to receive(:execute) do
          call_order << :auto_severity_override
          auto_override_result
        end

        ingest_reports

        expect(call_order).to eq([:auto_dismiss, :auto_severity_override, :auto_severity_override])
      end

      it 'calls AutoSeverityOverrideService for each scanner group with ingested IDs', :aggregate_failures do
        expect(Vulnerabilities::AutoSeverityOverrideService).to receive(:new)
          .with(pipeline, [vulnerability_1.id])
        expect(Vulnerabilities::AutoSeverityOverrideService).to receive(:new)
          .with(pipeline, [vulnerability_2.id])

        expect(Gitlab::AppJsonLogger).to receive(:debug).with(
          message: "Auto-overrode vulnerability severities",
          project_id: project.id,
          pipeline_id: pipeline.id,
          scanner: sast_scanner,
          count: 1
        )

        expect(Gitlab::AppJsonLogger).to receive(:debug).with(
          message: "Auto-overrode vulnerability severities",
          project_id: project.id,
          pipeline_id: pipeline.id,
          scanner: sbom_scanner,
          count: 1
        )

        ingest_reports
      end

      context 'when no vulnerabilities are overridden' do
        let(:auto_override_result) { ServiceResponse.success(payload: { count: 0 }) }

        it 'does not log a debug message' do
          expect(Gitlab::AppJsonLogger).not_to receive(:debug)

          ingest_reports
        end
      end

      context 'when auto-severity-override fails' do
        let(:auto_override_result) do
          ServiceResponse.error(message: 'Could not override severities', reason: 'something failed')
        end

        it 'logs an error message for each processed scan', :aggregate_failures do
          expect(Gitlab::AppJsonLogger).to receive(:error).once.with(
            message: "Failed to auto-override vulnerability severities",
            project_id: project.id,
            pipeline_id: pipeline.id,
            scanner: sast_scanner,
            error: "Could not override severities",
            reason: 'something failed'
          )

          expect(Gitlab::AppJsonLogger).to receive(:error).once.with(
            message: "Failed to auto-override vulnerability severities",
            project_id: project.id,
            pipeline_id: pipeline.id,
            scanner: sbom_scanner,
            error: "Could not override severities",
            reason: 'something failed'
          )

          ingest_reports
        end
      end

      context 'when unexpected exception occurs' do
        before do
          allow(auto_override_service).to receive(:execute).and_raise('something failed')
        end

        it 'logs an error message and tracks the exception', :aggregate_failures do
          expect(Gitlab::AppJsonLogger).to receive(:error).with(
            message: "Exception during auto-severity-override",
            project_id: project.id,
            pipeline_id: pipeline.id,
            error: 'something failed'
          )
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(StandardError)

          ingest_reports
        end
      end

      context 'when ingested IDs are empty' do
        let(:ids_1) { [] }
        let(:ids_2) { [] }

        it 'does not call AutoSeverityOverrideService' do
          expect(Vulnerabilities::AutoSeverityOverrideService).not_to receive(:new)

          ingest_reports
        end
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
