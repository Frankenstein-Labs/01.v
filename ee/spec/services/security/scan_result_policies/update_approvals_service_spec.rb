# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::UpdateApprovalsService, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let(:scanners) { %w[dependency_scanning] }
    let(:vulnerabilities_allowed) { 1 }
    let(:severity_levels) { %w[high unknown] }
    let(:vulnerability_states) { %w[detected new_needs_triage new_dismissed] }
    let(:approvals_required) { 2 }

    let_it_be_with_reload(:project) { create(:project, :repository) }
    let_it_be(:uuids) { Array.new(5) { SecureRandom.uuid } }
    let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }
    let_it_be_with_refind(:merge_request) do
      create(:merge_request, source_project: project, target_project: project,
        source_branch: 'feature', target_branch: 'master')
    end

    let_it_be(:pipeline) do
      create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
        ref: merge_request.source_branch, sha: merge_request.diff_head_sha)
    end

    let_it_be_with_refind(:target_pipeline) do
      create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
        ref: merge_request.target_branch, sha: merge_request.diff_base_sha)
    end

    let_it_be(:ds_build) do
      create(:ci_build, :success, name: 'ds_1', pipeline: pipeline, project: project)
    end

    let_it_be(:pipeline_scan) do
      create(:security_scan, :succeeded, project: project, build: ds_build, scan_type: 'dependency_scanning')
    end

    let_it_be(:scan_artifact) do
      create(:ee_ci_job_artifact, :dependency_scanning, job: ds_build, project: project)
    end

    let_it_be(:target_scan) do
      create(:security_scan, :succeeded,
        project: project,
        pipeline: target_pipeline,
        scan_type: 'dependency_scanning'
      )
    end

    let_it_be(:pipeline_findings) do
      uuids.map do |uuid|
        create(:security_finding, scan: pipeline_scan, scanner: scanner, severity: 'high', uuid: uuid)
      end
    end

    let_it_be_with_reload(:scan_result_policy_read) do
      create(:scan_result_policy_read, :with_approval_policy_rule, project: project)
    end

    let(:last_violation) { merge_request.scan_result_policy_violations.last }

    let!(:report_approver_rule) do
      create(:report_approver_rule, :scan_finding,
        merge_request: merge_request,
        approvals_required: approvals_required,
        scanners: scanners,
        vulnerabilities_allowed: vulnerabilities_allowed,
        severity_levels: severity_levels,
        vulnerability_states: vulnerability_states,
        scan_result_policy_read: scan_result_policy_read,
        approval_policy_rule: scan_result_policy_read.approval_policy_rule
      )
    end

    let(:service) { described_class.new(merge_request: merge_request, pipeline: pipeline) }

    before do
      allow(pipeline).to receive(:can_store_security_reports?).and_return(true)
      allow_next_found_instance_of(Ci::Pipeline) do |instance|
        allow(instance).to receive(:can_store_security_reports?).and_return(true)
      end
    end

    subject(:execute) { service.execute }

    shared_examples_for 'does not update approvals_required' do
      it do
        expect do
          execute
        end.not_to change { report_approver_rule.reload.approvals_required }
      end
    end

    shared_examples_for 'sets approvals_required to 0' do
      it do
        expect do
          execute
        end.to change { report_approver_rule.reload.approvals_required }.from(2).to(0)
      end
    end

    shared_examples_for 'new vulnerability_states' do |vulnerability_states|
      before do
        report_approver_rule.update!(vulnerability_states: vulnerability_states)
      end

      it 'does not call VulnerabilitiesCountService' do
        expect(Security::ScanResultPolicies::VulnerabilitiesCountService).not_to receive(:new)

        execute
      end
    end

    RSpec.shared_examples_for 'persists violation details' do
      let(:expected_context) { { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [target_pipeline.id] } }

      it 'persists violation details' do
        execute

        expect(last_violation.violation_data)
          .to match(
            'violations' => {
              'scan_finding' => { 'uuids' => expected_violations }
            },
            'context' => expected_context
          )
      end
    end

    RSpec.shared_examples_for 'persists all finding uuids in violation detail data' do
      let(:expected_newly_detected_uuids) { [] }
      let(:expected_previously_existing_uuids) { [] }

      it 'persists all finding uuids in violation detail data' do
        execute

        detail_records = last_violation.violation_details
        newly_detected_uuids = detail_records.newly_detected.pluck(:finding_uuid)
        previously_existing_uuids = detail_records.previously_existing.pluck(:finding_uuid)

        expect(newly_detected_uuids).to match_array(expected_newly_detected_uuids)
        expect(previously_existing_uuids).to match_array(expected_previously_existing_uuids)
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(dual_write_scan_result_policy_violation_details: false)
        end

        it 'still creates the violation' do
          expect { execute }.to change { merge_request.scan_result_policy_violations.count }.by(1)
        end

        it 'does not create violation detail rows' do
          expect { execute }.not_to change { Security::ScanResultPolicyViolationDetail.count }
        end
      end
    end

    RSpec.shared_examples_for 'persists error in violation details' do
      let(:expected_context) { { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [target_pipeline.id] } }

      it 'persists violation details' do
        execute

        expect(last_violation.violation_data)
          .to match(
            'errors' => [expected_error],
            'context' => expected_context
          )
      end
    end

    context 'without persisted policy' do
      let!(:report_approver_rule) { create(:report_approver_rule, :scan_finding, merge_request: merge_request) }

      it 'does not raise' do
        expect { execute }.not_to raise_error
      end
    end

    context 'when approval rules are empty' do
      let!(:report_approver_rule) { nil }

      it 'does not enqueue Security::GeneratePolicyViolationCommentWorker' do
        expect(Security::GeneratePolicyViolationCommentWorker).not_to receive(:perform_async)

        execute
      end
    end

    context 'when there are no violations and pipeline is manual' do
      let_it_be_with_refind(:pipeline) do
        create(:ee_ci_pipeline, :with_dependency_scanning_report,
          project: project,
          status: :manual,
          ref: merge_request.source_branch,
          sha: merge_request.diff_head_sha)
      end

      before do
        create(:security_scan, :succeeded, project: project, pipeline: pipeline, scan_type: 'dependency_scanning')
      end

      it_behaves_like 'sets approvals_required to 0'
    end

    context 'when security scan is removed in current pipeline' do
      let_it_be(:pipeline) { create(:ee_ci_pipeline, :success, project: project, ref: merge_request.source_branch) }
      let_it_be(:cs_build) do
        create(:ci_build, :success, name: 'cs_1', pipeline: pipeline, project: project)
      end

      let_it_be(:pipeline_scan) do
        create(:security_scan, :succeeded, project: project, build: cs_build, scan_type: 'container_scanning')
      end

      let_it_be(:scan_artifact) do
        create(:ee_ci_job_artifact, :container_scanning, job: cs_build, project: project)
      end

      context 'when approval rule scanners is empty' do
        let(:scanners) { [] }

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true
      end

      context 'when scan type matches the approval rule scanners' do
        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true

        it 'logs update' do
          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).once.ordered
            .with(
              workflow: 'approval_policy_evaluation',
              event: 'update_approvals',
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              message: 'Evaluating scan_finding rules from approval policies',
              pipeline_ids: [pipeline.id],
              project_path: project.full_path
            ).and_call_original

          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).once.ordered
            .with(
              workflow: 'approval_policy_evaluation',
              event: 'update_approvals',
              approval_rule_id: report_approver_rule.id,
              approval_rule_name: report_approver_rule.name,
              message: 'Updating MR approval rule',
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              reason: 'Scanner removed by MR',
              missing_scans: ['dependency_scanning'],
              project_path: project.full_path
            ).and_call_original

          execute
        end

        it_behaves_like 'persists error in violation details' do
          let(:expected_error) do
            {
              'error' => Security::ScanResultPolicyViolation::ERRORS[:scan_removed],
              'missing_scans' => ['dependency_scanning']
            }
          end
        end

        context 'when policy fails open' do
          before do
            report_approver_rule.scan_result_policy_read.update!(fallback_behavior: { fail: "open" })
            sp = report_approver_rule.approval_policy_rule&.security_policy&.reload
            sp&.update_column(:content,
              sp.content.deep_stringify_keys.merge('fallback_behavior' => { 'fail' => 'open' }))
          end

          it 'does not block the rule' do
            expect(::Gitlab::AppJsonLogger).not_to receive(:info).with(hash_including(reason: 'Scanner removed by MR'))

            execute
          end

          it 'creates a violation as warning' do
            execute

            expect(last_violation).to be_warn
          end
        end

        context 'when there are active scan execution policies' do
          let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [scan_execution_policy]) }
          let_it_be(:security_orchestration_policy_configuration) do
            create(:security_orchestration_policy_configuration, project: project)
          end

          let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
          let(:unblock_enabled) { true }
          let(:scan_execution_policy) do
            build(:scan_execution_policy,
              rules: [{ type: 'pipeline', branch_type: 'all' }],
              actions: [{ scan: 'dependency_scanning' }])
          end

          before do
            scan_result_policy_read.update!(policy_tuning: { unblock_rules_using_execution_policies: unblock_enabled })
            sp = report_approver_rule.approval_policy_rule&.security_policy&.reload
            sp&.update_column(:content, sp.content.deep_stringify_keys.merge(
              'policy_tuning' => { 'unblock_rules_using_execution_policies' => unblock_enabled }))
            allow_next_instance_of(Repository) do |repository|
              allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
            end
          end

          it_behaves_like 'sets approvals_required to 0'

          context 'when toggle "unblock_rules_using_execution_policies" is disabled' do
            let(:unblock_enabled) { false }

            it_behaves_like 'does not update approvals_required'
          end

          context 'when rule is not excludable' do
            let(:vulnerability_states) { %w[new_needs_triage detected] }

            it_behaves_like 'does not update approvals_required'
          end

          context 'when policy is not applicable for the source branch' do
            let(:scan_execution_policy) do
              build(:scan_execution_policy,
                rules: [{ type: 'pipeline', branches: %w[other] }],
                actions: [{ scan: 'dependency_scanning' }])
            end

            it_behaves_like 'does not update approvals_required'
          end

          context 'when the scanner in scan execution policies does not match approval rule scanners' do
            let(:scan_execution_policy) { build(:scan_execution_policy, actions: [{ scan: 'container_scanning' }]) }

            it_behaves_like 'does not update approvals_required'
          end
        end
      end

      context 'when scan type does not match the approval rule scanners' do
        let(:scanners) { %w[container_scanning] }

        let_it_be(:target_scan_container_scanning) do
          create(:security_scan, :succeeded,
            project: project,
            pipeline: target_pipeline,
            scan_type: 'container_scanning'
          )
        end

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
      end
    end

    context 'when security scan exists but did not succeed' do
      let(:scanners) { %w[sast] }

      let_it_be(:pipeline_with_failed_scan) do
        create(:ee_ci_pipeline, :success, project: project,
          ref: merge_request.source_branch, sha: merge_request.diff_head_sha)
      end

      let_it_be(:failed_scan_build) do
        create(:ci_build, :canceled, name: 'sast_1', pipeline: pipeline_with_failed_scan,
          project: project).tap do |build|
          create(:ee_ci_job_artifact, :sast, job: build, project: project)
        end
      end

      let_it_be_with_reload(:failed_scan) do
        create(:security_scan, :job_failed, project: project, build: failed_scan_build, scan_type: 'sast')
      end

      let_it_be(:target_sast_scan) do
        create(:security_scan, :succeeded,
          project: project,
          pipeline: target_pipeline,
          scan_type: 'sast'
        )
      end

      let(:service) { described_class.new(merge_request: merge_request, pipeline: pipeline_with_failed_scan) }

      before do
        allow(pipeline_with_failed_scan).to receive(:can_store_security_reports?).and_return(true)
      end

      it_behaves_like 'does not update approvals_required'
      it_behaves_like 'triggers policy bot comment', true

      it_behaves_like 'persists error in violation details' do
        let(:expected_context) do
          { 'pipeline_ids' => [pipeline_with_failed_scan.id], 'target_pipeline_ids' => [target_pipeline.id] }
        end

        let(:expected_error) do
          {
            'error' => Security::ScanResultPolicyViolation::ERRORS[:scan_not_succeeded],
            'missing_scans' => ['sast']
          }
        end
      end

      it 'logs the error' do
        expect(::Gitlab::AppJsonLogger)
          .to receive(:info).once.ordered
          .with(a_hash_including(
            event: 'update_approvals',
            message: 'Evaluating scan_finding rules from approval policies'
          )).and_call_original

        expect(::Gitlab::AppJsonLogger)
          .to receive(:info).once.ordered
          .with(a_hash_including(
            event: 'update_approvals',
            reason: 'Security scan did not complete successfully',
            missing_scans: ['sast']
          )).and_call_original

        execute
      end

      context 'with fail_open policy' do
        before do
          scan_result_policy_read.update!(fallback_behavior: { fail: "open" })
          sp = scan_result_policy_read.approval_policy_rule&.security_policy&.reload
          sp&.update_column(:content,
            sp.content.deep_stringify_keys.merge('fallback_behavior' => { 'fail' => 'open' }))
        end

        it 'does not block the rule' do
          expect(::Gitlab::AppJsonLogger).not_to receive(:info).with(
            hash_including(reason: 'Security scan did not complete successfully')
          )

          execute
        end

        it 'creates a violation as warning' do
          execute

          expect(last_violation).to be_warn
        end
      end

      context 'when approval rule has no approval_policy_source and a scan did not succeed' do
        before do
          report_approver_rule.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
        end

        it 'evaluates without error' do
          expect { execute }.not_to raise_error
        end
      end

      # rubocop:disable RSpec/MultipleMemoizedHelpers -- shared contexts expand lets beyond the 25-cop limit
      context 'with fallback_behavior divergent between approval_policy_rule and scan_result_policy_read' do
        include_context 'with approval rule backed by approval_policy_rule'
        include_context 'with divergent fallback_behavior across approval_policy_source'

        let(:approval_policy_source_read) { scan_result_policy_read }
        let(:approval_policy_source_rule) { report_approver_rule }
        let(:approval_policy_rule_trait) { :scan_finding }

        it 'does not block the rule (approval_policy_rule says fail_open)' do
          expect(::Gitlab::AppJsonLogger).not_to receive(:info).with(
            hash_including(reason: 'Security scan did not complete successfully')
          )

          execute
        end

        context 'when the deprecate_scan_result_policies flag is disabled' do
          include_context 'with deprecate_scan_result_policies flag disabled'

          it 'blocks the rule (scan_result_policy_read says fail_closed)' do
            expect(::Gitlab::AppJsonLogger).to receive(:info).with(
              hash_including(reason: 'Security scan did not complete successfully')
            ).and_call_original
            allow(::Gitlab::AppJsonLogger).to receive(:info).and_call_original

            execute
          end
        end
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers

      context 'when approval rule has no approval_policy_source' do
        before do
          report_approver_rule.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
        end

        it 'evaluates without error and does not block' do
          expect { execute }.not_to raise_error
        end
      end

      context 'when multiple scanners: one succeeded, one canceled' do
        let(:scanners) { %w[sast dependency_scanning] }

        let_it_be(:succeeded_ds_scan_on_same_pipeline) do
          ds_build = create(:ci_build, :success, name: 'ds_on_canceled', pipeline: pipeline_with_failed_scan,
            project: project)
          create(:security_scan, :succeeded, project: project, build: ds_build,
            scan_type: 'dependency_scanning')
        end

        it_behaves_like 'persists error in violation details' do
          let(:expected_context) do
            { 'pipeline_ids' => [pipeline_with_failed_scan.id], 'target_pipeline_ids' => [target_pipeline.id] }
          end

          let(:expected_error) do
            {
              'error' => Security::ScanResultPolicyViolation::ERRORS[:scan_not_succeeded],
              'missing_scans' => ['sast']
            }
          end
        end
      end

      context 'when scan has report_error status' do
        # Verify we catch all non-succeeded statuses, not just job_failed from canceled builds.
        # report_error occurs when the build completed but the security report could not be parsed.
        before do
          failed_scan.update!(status: Security::Scan.statuses[:report_error])
        end

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true
      end

      context 'when scan was retried and succeeded' do
        let_it_be(:retried_succeeded_scan) do
          succeeded_build = create(:ci_build, :success, name: 'sast_retry', pipeline: pipeline_with_failed_scan,
            project: project)
          create(:security_scan, :succeeded, project: project, build: succeeded_build, scan_type: 'sast')
        end

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
      end
    end

    context 'when a required scanner CI job failed and produced no artifact' do
      # Reproduces issue 604648: dependency_scanning job fails with allow_failure (no report artifact,
      # so no Security::Scan row) while another scanner succeeds. The failed scanner is also absent from
      # the target branch, so enforce_scans_presence! (:scan_removed) does not fire.
      let(:scanners) { %w[dependency_scanning] }

      let_it_be(:failed_job_pipeline) do
        create(:ee_ci_pipeline, :success, project: project,
          ref: merge_request.source_branch, sha: merge_request.diff_head_sha)
      end

      # A succeeding scanner with a report makes the pipeline "enforceable", so
      # UnenforceablePolicyRulesNotificationService defers to this service.
      let_it_be(:succeeded_build) do
        create(:ci_build, :success, name: 'secret_detection_1', pipeline: failed_job_pipeline, project: project)
      end

      let_it_be(:succeeded_scan) do
        create(:security_scan, :succeeded, project: project, build: succeeded_build, scan_type: 'secret_detection')
      end

      # dependency_scanning job failed (allow_failure keeps the pipeline green) and produced no artifact,
      # so no Security::Scan row exists. It is detected from its CI config reports declaration.
      let_it_be_with_reload(:failed_ds_build) do
        create(:ci_build, :failed, name: 'gemnasium-dependency_scanning', allow_failure: true,
          pipeline: failed_job_pipeline, project: project,
          options: { artifacts: { reports: { dependency_scanning: 'gl-dependency-scanning-report.json' } } })
      end

      let(:service) { described_class.new(merge_request: merge_request, pipeline: failed_job_pipeline) }

      before do
        allow(failed_job_pipeline).to receive(:can_store_security_reports?).and_return(true)
        # The failed scanner never succeeded on the target branch either.
        Security::Scan.where(pipeline: target_pipeline, scan_type: 'dependency_scanning').delete_all
      end

      it_behaves_like 'does not update approvals_required'
      it_behaves_like 'triggers policy bot comment', true

      it_behaves_like 'persists error in violation details' do
        let(:expected_context) do
          { 'pipeline_ids' => [failed_job_pipeline.id], 'target_pipeline_ids' => [target_pipeline.id] }
        end

        let(:expected_error) do
          {
            'error' => Security::ScanResultPolicyViolation::ERRORS[:scan_not_succeeded],
            'missing_scans' => ['dependency_scanning']
          }
        end
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(approval_policies_block_on_failed_scan_job: false)
        end

        # Preserves current (buggy) behavior: the MR remains mergeable.
        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
      end

      context 'with fail_open policy' do
        before do
          scan_result_policy_read.update!(fallback_behavior: { fail: "open" })
          sp = scan_result_policy_read.approval_policy_rule&.security_policy&.reload
          sp&.update_column(:content,
            sp.content.deep_stringify_keys.merge('fallback_behavior' => { 'fail' => 'open' }))
        end

        it 'does not block the rule' do
          expect(::Gitlab::AppJsonLogger).not_to receive(:info).with(
            hash_including(reason: 'Security scan job did not succeed and produced no report')
          )

          execute
        end

        it 'creates a violation as warning' do
          execute

          expect(last_violation).to be_warn
        end
      end

      context 'when the failed scanner is not listed in the rule' do
        let(:scanners) { %w[sast] }

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
      end

      context 'when the rule specifies no scanners (defaults to all supported)' do
        let(:scanners) { [] }

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true
      end

      context 'when several required scanners have unsuccessful jobs' do
        let(:scanners) { %w[dependency_scanning sast] }

        let_it_be(:failed_sast_build) do
          create(:ci_build, :canceled, name: 'semgrep-sast', pipeline: failed_job_pipeline, project: project,
            options: { artifacts: { reports: { sast: 'gl-sast-report.json' } } })
        end

        it_behaves_like 'does not update approvals_required'

        it_behaves_like 'persists error in violation details' do
          let(:expected_context) do
            { 'pipeline_ids' => [failed_job_pipeline.id], 'target_pipeline_ids' => [target_pipeline.id] }
          end

          let(:expected_error) do
            {
              'error' => Security::ScanResultPolicyViolation::ERRORS[:scan_not_succeeded],
              'missing_scans' => %w[sast dependency_scanning]
            }
          end
        end
      end

      context 'when the job was retried and the retry succeeded' do
        # `.latest` must ignore the superseded failed attempt, otherwise a green retry keeps blocking.
        before do
          failed_ds_build.update!(retried: true)
          create(:ci_build, :success, name: 'gemnasium-dependency_scanning', pipeline: failed_job_pipeline,
            project: project,
            options: { artifacts: { reports: { dependency_scanning: 'gl-dependency-scanning-report.json' } } })
        end

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
      end

      describe 'job status handling' do
        # Non-terminal statuses must not block a scan that is still in progress, and manual/skipped
        # jobs are a configuration choice rather than a scan that ran without producing a verdict.
        where(:job_status, :expected_approvals_required) do
          :failed    | 2
          :canceled  | 2
          :canceling | 2
          :running   | 0
          :pending   | 0
          :created   | 0
          :manual    | 0
          :skipped   | 0
        end

        with_them do
          before do
            failed_ds_build.update!(status: job_status.to_s)
          end

          it 'blocks only when the job terminated without succeeding' do
            execute

            expect(report_approver_rule.reload.approvals_required).to eq(expected_approvals_required)
          end
        end
      end
    end

    context 'when not all security scans are present in the target pipeline' do
      let(:scanners) { %w[dependency_scanning container_scanning] }
      let_it_be(:source_scan_container_scanning) do
        create(:security_scan, :succeeded,
          project: project,
          pipeline: pipeline,
          scan_type: 'container_scanning'
        )
      end

      it_behaves_like 'persists violation details' do
        let(:expected_violations) { { 'newly_detected' => array_including(uuids) } }
      end

      describe 'logging' do
        it 'logs information about the missing scans' do
          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).with(a_hash_including(event: 'update_approvals')).at_least(:once)
          expect(::Gitlab::AppJsonLogger)
            .to receive(:info)
            .with(
              workflow: 'approval_policy_evaluation',
              event: 'approval_policy_missing_target_scan',
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              message: 'Enforced scanner missing on target branch',
              missing_scanners: %w[container_scanning],
              project_path: project.full_path,
              target_pipeline_id: target_pipeline.id,
              target_pipeline_status: 'success',
              source_pipeline_scans: %w[dependency_scanning container_scanning],
              target_pipeline_scans: %w[dependency_scanning]
            )

          execute
        end

        context 'when an alternative target pipeline could have been chosen using time_window' do
          let_it_be_with_refind(:time_window_pipeline) do
            create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
              ref: merge_request.target_branch,
              sha: 'previous-sha',
              created_at: target_pipeline.created_at - 5.minutes)
          end

          let_it_be(:time_window_pipeline_scan) do
            create(:security_scan, :succeeded, pipeline: time_window_pipeline, scan_type: 'dependency_scanning')
          end

          let_it_be_with_refind(:latest_target_pipeline_without_artifacts) do
            create(:ee_ci_pipeline, :skipped, project: project,
              ref: merge_request.target_branch, sha: merge_request.diff_base_sha)
          end

          before do
            # Ensure that target_pipeline previously created doesn't have security reports
            target_pipeline.builds.delete_all
          end

          it 'logs additional information' do
            expect(::Gitlab::AppJsonLogger)
              .to receive(:info).with(a_hash_including(event: 'update_approvals')).at_least(:once)
            expect(::Gitlab::AppJsonLogger)
              .to receive(:info).with(a_hash_including(event: 'approval_policy_pipeline_selection')).at_least(:once)
            expect(::Gitlab::AppJsonLogger)
              .to receive(:info)
              .with(a_hash_including(
                event: 'approval_policy_missing_target_scan',
                pipeline_within_time_window_id: time_window_pipeline.id,
                pipeline_within_time_window_status: 'success',
                pipeline_within_time_window_scans: %w[dependency_scanning]
              ))

            execute
          end
        end
      end
    end

    context 'when there are no violated approval rules' do
      let(:vulnerabilities_allowed) { 100 }

      it_behaves_like 'sets approvals_required to 0'
      it_behaves_like 'triggers policy bot comment', false
      it_behaves_like 'merge request without scan result violations'

      context 'when there are other scan_finding violations' do
        let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project, name: 'master') }
        let_it_be(:scan_result_policy_read_other_scan_finding) do
          create(:scan_result_policy_read, :with_approval_policy_rule, project: project)
        end

        let_it_be(:approval_project_rule_other) do
          create(:approval_project_rule, :scan_finding, project: project, approvals_required: 1,
            scan_result_policy_read: scan_result_policy_read_other_scan_finding,
            approval_policy_rule: scan_result_policy_read_other_scan_finding.approval_policy_rule,
            protected_branches: [protected_branch])
        end

        let_it_be(:approver_rule_other) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request, vulnerability_states: ['detected'],
            approval_project_rule: approval_project_rule_other, approvals_required: 1,
            scan_result_policy_read: scan_result_policy_read_other_scan_finding,
            approval_policy_rule: scan_result_policy_read_other_scan_finding.approval_policy_rule)
        end

        let_it_be_with_reload(:other_violation) do
          create(:scan_result_policy_violation, scan_result_policy_read: scan_result_policy_read_other_scan_finding,
            approval_policy_rule: scan_result_policy_read_other_scan_finding.approval_policy_rule,
            merge_request: merge_request)
        end

        it_behaves_like 'triggers policy bot comment', true

        context 'when there are other running violations' do
          before do
            create(:scan_result_policy_violation, merge_request: merge_request, status: :running)
          end

          it_behaves_like 'does not trigger policy bot comment'
        end
      end
    end

    context 'when there are no required approvals' do
      let(:approvals_required) { 0 }

      it_behaves_like 'triggers policy bot comment', true
      it_behaves_like 'persists violation details' do
        let(:expected_violations) { { 'newly_detected' => array_including(uuids) } }
      end
    end

    context 'when newly_detected findings exceed MAX_VIOLATIONS' do
      let(:approvals_required) { 0 }
      let(:max_violations) { 2 }
      let(:extra_uuids) { Array.new(max_violations + 3) { SecureRandom.uuid } }

      before do
        stub_const('Security::ScanResultPolicyViolation::MAX_VIOLATIONS', max_violations)

        extra_uuids.each do |uuid|
          create(:security_finding, scan: pipeline_scan, scanner: scanner, severity: 'high', uuid: uuid)
        end
      end

      it 'trims violation_data to MAX_VIOLATIONS + 1 UUIDs' do
        execute

        newly_detected = last_violation.violation_data.dig('violations', 'scan_finding', 'uuids', 'newly_detected')
        expect(newly_detected.size).to eq(max_violations + 1)
      end

      it 'does not include a previously_existing key when all findings are newly detected' do
        execute

        uuids_data = last_violation.violation_data.dig('violations', 'scan_finding', 'uuids')
        expect(uuids_data).not_to have_key('previously_existing')
        expect(uuids_data).to have_key('newly_detected')
      end

      it_behaves_like 'persists all finding uuids in violation detail data' do
        let(:expected_newly_detected_uuids) { uuids + extra_uuids }
      end
    end

    context 'when previously_existing findings exceed MAX_VIOLATIONS' do
      let(:approvals_required) { 0 }
      let(:max_violations) { 2 }
      let(:vulnerability_states) { %w[detected new_needs_triage] }
      let(:extra_uuids) { Array.new(max_violations + 3) { SecureRandom.uuid } }

      before do
        stub_const('Security::ScanResultPolicyViolation::MAX_VIOLATIONS', max_violations)

        all_uuids = uuids + extra_uuids
        all_uuids.each do |uuid|
          create(:security_finding, scan: target_scan, scanner: scanner, severity: 'high', uuid: uuid)
          vulnerability = create(:vulnerability, :detected, project: project)
          create(:vulnerabilities_finding, project: project, scanner: scanner, uuid: uuid,
            vulnerability: vulnerability)
        end

        extra_uuids.each do |uuid|
          create(:security_finding, scan: pipeline_scan, scanner: scanner, severity: 'high', uuid: uuid)
        end
      end

      it 'trims previously_existing in violation_data to MAX_VIOLATIONS + 1 UUIDs' do
        execute

        previously_existing = last_violation.violation_data.dig(
          'violations', 'scan_finding', 'uuids', 'previously_existing'
        )
        expect(previously_existing.size).to eq(max_violations + 1)
      end

      it 'does not include a newly_detected key when all findings are previously existing' do
        execute

        uuids_data = last_violation.violation_data.dig('violations', 'scan_finding', 'uuids')
        expect(uuids_data).not_to have_key('newly_detected')
        expect(uuids_data).to have_key('previously_existing')
      end

      it_behaves_like 'persists all finding uuids in violation detail data' do
        let(:expected_previously_existing_uuids) { uuids + extra_uuids }
      end
    end

    context 'when targeting an unprotected branch' do
      let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project, name: 'master') }
      let!(:report_approver_project_rule) do
        create(:approval_project_rule, :scan_finding, project: project,
          approvals_required: approvals_required, scan_result_policy_read: scan_result_policy_read,
          protected_branches: [protected_branch])
      end

      let!(:report_approver_rule) do
        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          approval_project_rule: report_approver_project_rule,
          approvals_required: approvals_required, scan_result_policy_read: scan_result_policy_read)
      end

      before do
        merge_request.update!(target_branch: 'non-protected')
      end

      it_behaves_like 'triggers policy bot comment', false
    end

    context 'when target pipeline is nil' do
      let_it_be_with_refind(:merge_request) do
        create(:merge_request, source_project: project, target_project: project,
          source_branch: 'feature', target_branch: 'target-branch')
      end

      it_behaves_like 'does not update approvals_required'
      it_behaves_like 'triggers policy bot comment', true
      it_behaves_like 'persists violation details' do
        let(:expected_context) { { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [] } }
        let(:expected_violations) { { 'newly_detected' => array_including(uuids) } }
      end

      it 'logs information about the missing scans' do
        expect(::Gitlab::AppJsonLogger)
          .to receive(:info).with(a_hash_including(event: 'update_approvals')).at_least(:once)
        expect(::Gitlab::AppJsonLogger)
          .to receive(:info)
          .with(
            workflow: 'approval_policy_evaluation',
            event: 'approval_policy_missing_target_scan',
            merge_request_id: merge_request.id,
            merge_request_iid: merge_request.iid,
            message: 'Enforced scanner missing on target branch',
            missing_scanners: %w[dependency_scanning],
            project_path: project.full_path,
            target_pipeline_id: nil,
            target_pipeline_status: nil,
            source_pipeline_scans: %w[dependency_scanning],
            target_pipeline_scans: []
          )

        execute
      end

      context 'with missing scan in the source pipeline' do
        before do
          report_approver_rule.update!(scanners: %i[container_scanning])
        end

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true

        it_behaves_like 'persists error in violation details' do
          let(:expected_context) { { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [] } }
          let(:expected_error) do
            {
              'error' => Security::ScanResultPolicyViolation::ERRORS[:scan_removed],
              'missing_scans' => ['container_scanning']
            }
          end
        end
      end
    end

    context 'with merged results pipeline' do
      let_it_be(:merge_base_pipeline) do
        create(
          :ee_ci_pipeline,
          :success,
          :with_dependency_scanning_report,
          merge_request: merge_request,
          project: project,
          ref: merge_request.target_branch,
          sha: Digest::SHA256.hexdigest('target commit'))
      end

      let_it_be(:merged_results_pipeline) do
        create(:ee_ci_pipeline,
          :success,
          source: :merge_request_event,
          merge_request: merge_request,
          project: project,
          source_sha: merge_request.diff_head_sha,
          target_sha: merge_base_pipeline.sha,
          ref: merge_request.merge_ref_path,
          sha: Digest::SHA256.hexdigest('merge commit'))
      end

      let_it_be(:merge_base_pipeline_scan) do
        create(:security_scan, :succeeded, project: project, pipeline: merge_base_pipeline,
          scan_type: 'dependency_scanning')
      end

      let!(:merge_base_pipeline_finding) do
        create(:security_finding, scan: merge_base_pipeline_scan, severity: 'high', scanner: scanner,
          uuid: existing_uuid)
      end

      let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
      let(:vulnerabilities_allowed) { uuids.count - 1 }
      let(:existing_uuid) { uuids.first }

      before do
        merge_request.update_head_pipeline
      end

      context 'when there are no violated approval rules' do
        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
      end

      context 'when there are violated approval rules' do
        let(:existing_uuid) { SecureRandom.uuid }

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true

        context 'when no common ancestor pipeline has security reports' do
          before do
            merge_base_pipeline_scan.delete
          end

          it_behaves_like 'does not update approvals_required'
          it_behaves_like 'triggers policy bot comment', true
        end
      end
    end

    context 'when there is no target pipeline with the common ancestor' do
      let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
      let(:vulnerabilities_allowed) { uuids.count - 1 }

      before do
        target_pipeline.delete
      end

      context 'with a fallback target branch pipeline' do
        let_it_be(:latest_target_branch_pipeline) do
          create(
            :ee_ci_pipeline,
            :success,
            merge_request: merge_request,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha)
        end

        let_it_be(:diff_start_sha_pipeline_scan) do
          create(:security_scan, :succeeded, project: project, pipeline: latest_target_branch_pipeline,
            scan_type: 'dependency_scanning')
        end

        let!(:diff_start_sha_pipeline_finding) do
          create(:security_finding, scan: diff_start_sha_pipeline_scan, severity: 'high', scanner: scanner,
            uuid: existing_uuid)
        end

        context 'when there are no violated approval rules' do
          let(:existing_uuid) { uuids.first }

          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', false
        end

        context 'when there are violated approval rules' do
          let(:existing_uuid) { SecureRandom.uuid }

          it_behaves_like 'does not update approvals_required'
          it_behaves_like 'triggers policy bot comment', true
        end
      end

      context 'with a target pipeline matching diff_start_sha' do
        let_it_be(:diff_start_sha_target_pipeline) do
          create(
            :ee_ci_pipeline,
            :success,
            :with_sast_report,
            merge_request: merge_request,
            project: project,
            ref: merge_request.target_branch,
            merge_requests_as_head_pipeline: [merge_request],
            sha: merge_request.diff_start_sha)
        end

        # Created to ensure we compare with diff_start_sha and not with a fallback pipeline for the target branch
        let_it_be(:latest_target_branch_pipeline) do
          create(
            :ee_ci_pipeline,
            :success,
            merge_request: merge_request,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha)
        end

        let_it_be(:diff_start_sha_pipeline_scan) do
          create(:security_scan, :succeeded, project: project, pipeline: diff_start_sha_target_pipeline,
            scan_type: 'dependency_scanning')
        end

        let!(:diff_start_sha_pipeline_finding) do
          create(:security_finding, scan: diff_start_sha_pipeline_scan, severity: 'high', scanner: scanner,
            uuid: existing_uuid)
        end

        context 'when there are no violated approval rules' do
          let(:existing_uuid) { uuids.first }

          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', false
        end

        context 'when there are violated approval rules' do
          let(:existing_uuid) { SecureRandom.uuid }

          it_behaves_like 'does not update approvals_required'
          it_behaves_like 'triggers policy bot comment', true
        end
      end
    end

    context 'when there are findings in the current pipeline exceed the allowed limit' do
      it_behaves_like 'new vulnerability_states', ['new_needs_triage']
      it_behaves_like 'new vulnerability_states', ['new_dismissed']
      it_behaves_like 'new vulnerability_states', %w[new_dismissed new_needs_triage]

      it_behaves_like 'does not update approvals_required'
      it_behaves_like 'triggers policy bot comment', true

      it_behaves_like 'persists violation details' do
        let(:expected_violations) { { 'newly_detected' => array_including(uuids) } }
      end

      context 'when vulnerability_states are new_dismissed' do
        let(:vulnerability_states) { %w[new_dismissed] }

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
      end

      context 'when vulnerability_states are new_needs_triage' do
        let(:vulnerability_states) { %w[new_needs_triage] }

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true
      end

      context 'when new findings are introduced to previously existing findings and it exceeds the allowed limit' do
        let(:vulnerabilities_allowed) { 4 }
        let_it_be(:new_finding_uuid) { uuids[4] }
        let_it_be(:previously_existing_finding_uuids) { uuids[0..3] }
        let_it_be(:target_pipeline_findings) do
          create_findings_with_vulnerabilities(target_scan, previously_existing_finding_uuids)
        end

        it 'logs update' do
          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).once.ordered
            .with(
              workflow: 'approval_policy_evaluation',
              event: 'update_approvals',
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              message: 'Evaluating scan_finding rules from approval policies',
              pipeline_ids: [pipeline.id],
              project_path: project.full_path
            ).and_call_original

          expect(::Gitlab::AppJsonLogger)
            .to receive(:info).once.ordered
            .with(
              workflow: 'approval_policy_evaluation',
              event: 'update_approvals',
              approval_rule_id: report_approver_rule.id,
              approval_rule_name: report_approver_rule.name,
              message: 'Updating MR approval rule',
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              reason: 'scan_finding rule violated',
              project_path: project.full_path
            ).and_call_original

          execute
        end

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true

        it_behaves_like 'persists violation details' do
          let(:expected_violations) do
            {
              'newly_detected' => [new_finding_uuid],
              'previously_existing' => array_including(previously_existing_finding_uuids)
            }
          end
        end

        context 'when there are no new dismissed vulnerabilities' do
          let(:vulnerabilities_allowed) { 0 }

          context 'when vulnerability_states is new_needs_triage' do
            let(:vulnerability_states) { %w[new_needs_triage] }

            it_behaves_like 'new vulnerability_states', ['new_needs_triage']
            it_behaves_like 'does not update approvals_required'
          end

          context 'when vulnerability_states are new_dismissed and new_needs_triage' do
            let(:vulnerability_states) { %w[new_dismissed new_needs_triage] }

            it_behaves_like 'new vulnerability_states', %w[new_dismissed new_needs_triage]
            it_behaves_like 'does not update approvals_required'
          end

          context 'when vulnerability_states are empty array' do
            let(:vulnerability_states) { [] }

            it_behaves_like 'new vulnerability_states', []
            it_behaves_like 'does not update approvals_required'
          end

          context 'when vulnerability_states is new_dismissed' do
            let(:vulnerability_states) { %w[new_dismissed] }

            it_behaves_like 'new vulnerability_states', ['new_dismissed']
            it_behaves_like 'sets approvals_required to 0'
            it_behaves_like 'merge request without scan result violations'
          end
        end

        context 'when there are new dismissed vulnerabilities' do
          let(:vulnerabilities_allowed) { 0 }

          before_all do
            vulnerability = create(:vulnerability, :dismissed, project: project)
            create(:vulnerabilities_finding, project: project, uuid: new_finding_uuid,
              vulnerability_id: vulnerability.id)
          end

          context 'when vulnerability_states is new_dismissed' do
            let(:vulnerability_states) { %w[new_dismissed] }

            it_behaves_like 'new vulnerability_states', ['new_dismissed']
            it_behaves_like 'does not update approvals_required'

            it_behaves_like 'persists violation details' do
              let(:expected_violations) do
                { 'newly_detected' => [new_finding_uuid] }
              end
            end
          end

          context 'when vulnerability_states are new_dismissed and new_needs_triage' do
            let(:vulnerability_states) { %w[new_dismissed new_needs_triage] }

            it_behaves_like 'new vulnerability_states', %w[new_dismissed new_needs_triage]
            it_behaves_like 'does not update approvals_required'

            it_behaves_like 'persists violation details' do
              let(:expected_violations) do
                { 'newly_detected' => [new_finding_uuid] }
              end
            end
          end

          context 'when vulnerability_states are empty array' do
            let(:vulnerability_states) { [] }

            it_behaves_like 'new vulnerability_states', []
            it_behaves_like 'does not update approvals_required'

            it_behaves_like 'persists violation details' do
              let(:expected_violations) do
                { 'newly_detected' => [new_finding_uuid] }
              end
            end
          end

          context 'when vulnerability_states is new_needs_triage' do
            let(:vulnerability_states) { %w[new_needs_triage] }

            it_behaves_like 'new vulnerability_states', ['new_needs_triage']
            it_behaves_like 'sets approvals_required to 0'
            it_behaves_like 'merge request without scan result violations'
          end
        end

        context 'when the approval rules had approvals removed' do
          let_it_be(:approval_project_rule) do
            create(:approval_project_rule, :scan_finding, project: project, approvals_required: 2,
              scan_result_policy_read: scan_result_policy_read)
          end

          let!(:report_approver_rule) do
            create(:report_approver_rule, :scan_finding,
              approval_project_rule: approval_project_rule,
              merge_request: merge_request,
              approvals_required: 0,
              scanners: scanners,
              vulnerabilities_allowed: vulnerabilities_allowed,
              severity_levels: severity_levels,
              vulnerability_states: vulnerability_states,
              scan_result_policy_read: scan_result_policy_read
            )
          end

          before do
            create(:protected_branch, project: project, name: merge_request.target_branch)
          end

          it 'resets the required approvals' do
            expect { execute }.to change { report_approver_rule.reload.approvals_required }.to(2)
          end
        end
      end
    end

    context 'when there are preexisting findings that exceed the allowed limit' do
      context 'when target pipeline is not empty' do
        let_it_be(:target_pipeline_findings) { create_findings_with_vulnerabilities(target_scan, uuids) }
        let(:vulnerability_states) { %w[detected] }

        # If vulnerability_states only include previously-existing statuses,
        # the updates are handled by SyncPreexistingStatesApprovalRulesService
        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'does not trigger policy bot comment'

        it 'does not add violations' do
          expect { execute }.not_to change { merge_request.scan_result_policy_violations.count }.from(0)
        end

        context 'when vulnerabilities count does not exceed the allowed limit' do
          let(:vulnerabilities_allowed) { 6 }

          it_behaves_like 'does not update approvals_required'
          it_behaves_like 'does not trigger policy bot comment'

          it 'does not add violations' do
            expect { execute }.not_to change { merge_request.scan_result_policy_violations.count }.from(0)
          end
        end

        context 'when vulnerability_states has only newly detected' do
          let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }

          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', false
          it_behaves_like 'merge request without scan result violations'
        end

        context 'when vulnerability_states are empty array' do
          let(:vulnerability_states) { [] }

          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', false
          it_behaves_like 'merge request without scan result violations'
        end

        context 'when vulnerability_states include detected' do
          let(:base_states) { %w[detected] }

          [
            %w[new_needs_triage],
            %w[new_dismissed],
            %w[new_needs_triage new_dismissed]
          ].each do |states|
            context "and #{states}" do
              let(:vulnerability_states) { base_states + states }

              it_behaves_like 'does not update approvals_required'
              it_behaves_like 'triggers policy bot comment', true
              it_behaves_like 'persists violation details' do
                let(:expected_violations) { { 'previously_existing' => array_including(uuids) } }
              end
            end
          end
        end
      end

      context 'when target pipeline is nil' do
        let_it_be_with_refind(:merge_request) do
          create(:merge_request, source_project: project, target_project: project,
            source_branch: 'feature', target_branch: 'target-branch')
        end

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true
        it_behaves_like 'persists violation details' do
          let(:expected_violations) { { 'newly_detected' => array_including(uuids) } }
          let(:expected_context) { { 'pipeline_ids' => [pipeline.id], 'target_pipeline_ids' => [] } }
        end
      end
    end

    context 'when previously existing findings have states not tracked by the policy' do
      let(:vulnerabilities_allowed) { 0 }

      let_it_be(:target_pipeline_findings) do
        uuids.map do |uuid|
          create(:security_finding, scan: target_scan, scanner: scanner, severity: 'high', uuid: uuid)
        end
      end

      let_it_be(:confirmed_uuid) { uuids[0] }
      let_it_be(:detected_uuid) { uuids[1] }
      let_it_be(:dismissed_uuid) { uuids[2] }
      let_it_be(:resolved_uuid) { uuids[3] }

      before_all do
        {
          confirmed_uuid => :confirmed,
          detected_uuid => :detected,
          dismissed_uuid => :dismissed,
          resolved_uuid => :resolved
        }.each do |uuid, state|
          vulnerability = create(:vulnerability, state, project: project)
          create(:vulnerabilities_finding, project: project, scanner: scanner, uuid: uuid, vulnerability: vulnerability)
        end
      end

      context 'when policy tracks confirmed and new_needs_triage' do
        let(:vulnerability_states) { %w[confirmed new_needs_triage] }

        it 'only includes confirmed UUID in previously_existing violation data' do
          execute

          previously_existing = last_violation.violation_data.dig(
            'violations', 'scan_finding', 'uuids', 'previously_existing'
          )

          expect(previously_existing).to contain_exactly(confirmed_uuid)
        end
      end

      context 'when policy tracks detected and confirmed' do
        let(:vulnerability_states) { %w[detected confirmed new_needs_triage] }

        it 'excludes dismissed and resolved UUIDs from previously_existing violation data' do
          execute

          previously_existing = last_violation.violation_data.dig(
            'violations', 'scan_finding', 'uuids', 'previously_existing'
          )
          expect(previously_existing).to contain_exactly(confirmed_uuid, detected_uuid)
        end
      end
    end

    context 'with multiple pipeline' do
      let_it_be(:related_uuids) { Array.new(5) { SecureRandom.uuid } }
      let_it_be(:related_source_pipeline) do
        create(:ee_ci_pipeline, :success,
          project: project,
          source: :schedule,
          ref: merge_request.source_branch,
          sha: pipeline.sha
        )
      end

      let_it_be(:related_target_pipeline) do
        create(:ee_ci_pipeline, :success,
          project: project,
          source: :schedule,
          ref: merge_request.target_branch,
          sha: target_pipeline.sha
        )
      end

      let_it_be(:related_pipeline_scan) do
        create(:security_scan, :succeeded,
          project: project,
          pipeline: related_source_pipeline,
          scan_type: 'dependency_scanning'
        )
      end

      let_it_be(:related_target_scan) do
        create(:security_scan, :succeeded,
          project: project,
          pipeline: related_target_pipeline,
          scan_type: 'dependency_scanning'
        )
      end

      context 'when findings in the main pipeline violate the policy' do
        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true
      end

      context 'when no pipeline can store security reports' do
        before do
          allow(pipeline).to receive(:can_store_security_reports?).and_return(false)
          allow(service).to receive(:related_pipeline_with_security_reports_exists?).and_return(false)
        end

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'does not trigger policy bot comment'

        it 'logs a message' do
          expect(::Gitlab::AppJsonLogger).to receive(:info).with(a_hash_including(
            workflow: 'approval_policy_evaluation',
            event: 'update_approvals',
            message: 'No security reports found for the pipeline'))

          execute
        end
      end

      context 'when findings in the main pipeline do not violate the policy' do
        let(:severity_levels) { %w[medium] }

        context 'without findings in the related pipelines' do
          it_behaves_like 'sets approvals_required to 0'
          it_behaves_like 'triggers policy bot comment', false

          context 'when main pipeline cannot store security reports and a related pipeline can' do
            before do
              allow(pipeline).to receive(:can_store_security_reports?).and_return(false)
              allow(service).to receive(:related_pipeline_with_security_reports_exists?).and_return(true)
            end

            it_behaves_like 'sets approvals_required to 0'
            it_behaves_like 'triggers policy bot comment', false
          end
        end

        context 'with findings in the related pipelines violating the policy' do
          before_all do
            related_uuids.each do |uuid|
              create(:security_finding, scan: related_pipeline_scan, scanner: scanner, severity: 'medium', uuid: uuid)
              create(:security_finding, scan: related_target_scan, scanner: scanner, severity: 'medium', uuid: uuid)

              vulnerability = create(:vulnerability, project: project)
              create(:vulnerabilities_finding, project: project, uuid: uuid, vulnerability: vulnerability)
            end
          end

          it_behaves_like 'does not update approvals_required'
          it_behaves_like 'triggers policy bot comment', true

          context 'when main pipeline cannot store security reports and a related pipeline can' do
            before do
              allow(pipeline).to receive(:can_store_security_reports?).and_return(false)
              allow(service).to receive(:related_pipeline_with_security_reports_exists?).and_return(true)
            end

            it_behaves_like 'does not update approvals_required'
            it_behaves_like 'triggers policy bot comment', true
          end

          context 'when security scan is removed in related pipeline' do
            let_it_be(:pipeline) do
              create(:ee_ci_pipeline, :success,
                project: project,
                ref: merge_request.source_branch
              )
            end

            it_behaves_like 'does not update approvals_required'
            it_behaves_like 'triggers policy bot comment', true
          end
        end
      end
    end

    context 'when the approval rule has vulnerability attributes' do
      let(:report_approver_rule) { nil }
      let_it_be_with_reload(:policy) do
        create(:scan_result_policy_read, project: project, vulnerability_attributes: { fix_available: true })
      end

      let!(:approval_rule) do
        create(:approval_project_rule, :scan_finding, project: project, scanners: scanners,
          scan_result_policy_read: policy)
      end

      let!(:mr_rule) do
        create(:approval_merge_request_rule, :scan_finding, scanners: scanners, merge_request: merge_request,
          approval_project_rule: approval_rule)
      end

      specify do
        expect(Security::ScanResultPolicies::FindingsFinder).to receive(:new).at_least(:once).with(
          anything,
          anything,
          hash_including(fix_available: true, false_positive: nil, known_exploited: nil, epss_score: {},
            enrichment_data_unavailable_action: nil
          )
        ).and_call_original

        execute
      end

      context 'when vulnerability_attributes are nil' do
        before do
          policy.update!(vulnerability_attributes: nil)
        end

        specify do
          expect(Security::ScanResultPolicies::FindingsFinder).to receive(:new).at_least(:once).with(
            anything,
            anything,
            hash_including(fix_available: nil, false_positive: nil, known_exploited: nil, epss_score: {},
              enrichment_data_unavailable_action: nil
            )
          ).and_call_original

          execute
        end
      end

      context 'when vulnerability_attributes include CVE enrichment filters' do
        before do
          policy.update!(vulnerability_attributes: {
            fix_available: true,
            known_exploited: true,
            epss_score: { operator: 'greater_than', value: 0.5 },
            enrichment_data_unavailable: { action: 'block' }
          })
        end

        specify do
          expect(Security::ScanResultPolicies::FindingsFinder).to receive(:new).at_least(:once).with(
            anything,
            anything,
            hash_including(
              fix_available: true,
              false_positive: nil,
              known_exploited: true,
              epss_score: { operator: 'greater_than', value: 0.5 },
              enrichment_data_unavailable_action: 'block'
            )
          ).and_call_original

          execute
        end
      end
    end

    context 'with atomic scanner rule criteria' do
      let_it_be(:atomic_policy_rule) do
        create(:approval_policy_rule, :scan_finding, content: {
          'type' => 'scan_finding',
          'branches' => [],
          'scanners' => [
            { 'type' => 'dependency_scanning', 'vulnerability_attributes' => { 'fix_available' => true } }
          ],
          'severity_levels' => %w[high],
          'vulnerability_states' => %w[new_needs_triage new_dismissed],
          'vulnerabilities_allowed' => 0
        })
      end

      let!(:report_approver_rule) do
        create(:report_approver_rule, :scan_finding,
          merge_request: merge_request,
          approvals_required: approvals_required,
          scanners: scanners,
          vulnerabilities_allowed: vulnerabilities_allowed,
          severity_levels: severity_levels,
          vulnerability_states: vulnerability_states,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: atomic_policy_rule
        )
      end

      it 'uses GroupedFindingsEvaluator for evaluation' do
        expect(Security::ScanResultPolicies::GroupedFindingsEvaluator)
          .to receive(:new).at_least(:once).and_call_original

        execute
      end

      context 'when grouped findings violate the policy' do
        let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
        let(:vulnerabilities_allowed) { 0 }

        before_all do
          Array.new(5) { SecureRandom.uuid }.each do |uuid|
            create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner,
              severity: 'high', uuid: uuid)
          end
        end

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true
      end

      context 'when grouped findings do not violate the policy' do
        let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
        let(:vulnerabilities_allowed) { 100 }

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
      end

      context 'when group result has per-group vulnerabilities_allowed override' do
        let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
        let(:vulnerabilities_allowed) { 0 }

        let_it_be(:atomic_policy_rule_with_allowed) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              {
                'type' => 'dependency_scanning',
                'vulnerability_attributes' => { 'fix_available' => true },
                'vulnerabilities_allowed' => 100
              }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[new_needs_triage new_dismissed],
            'vulnerabilities_allowed' => 0
          })
        end

        let!(:report_approver_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            approvals_required: approvals_required,
            scanners: scanners,
            vulnerabilities_allowed: vulnerabilities_allowed,
            severity_levels: severity_levels,
            vulnerability_states: vulnerability_states,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: atomic_policy_rule_with_allowed
          )
        end

        it_behaves_like 'sets approvals_required to 0'
      end

      context 'when group result has mixed vulnerability_states including pre-existing' do
        let(:vulnerability_states) { %w[detected new_needs_triage] }
        let(:vulnerabilities_allowed) { 0 }

        let_it_be(:atomic_policy_rule_mixed_states) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              {
                'type' => 'dependency_scanning',
                'vulnerability_attributes' => { 'fix_available' => true }
              }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[detected new_needs_triage],
            'vulnerabilities_allowed' => 0
          })
        end

        let!(:report_approver_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            approvals_required: approvals_required,
            scanners: scanners,
            vulnerabilities_allowed: vulnerabilities_allowed,
            severity_levels: severity_levels,
            vulnerability_states: vulnerability_states,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: atomic_policy_rule_mixed_states
          )
        end

        it 'calls VulnerabilitiesCountService for pre-existing states' do
          expect(Security::ScanResultPolicies::VulnerabilitiesCountService).to receive(:new)
            .with(hash_including(states: %w[detected]))
            .and_call_original

          execute
        end
      end

      context 'when no findings exist in the source pipeline' do
        let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
        let(:vulnerabilities_allowed) { 0 }
        let(:severity_levels) { %w[critical] }

        it_behaves_like 'sets approvals_required to 0'
        it_behaves_like 'triggers policy bot comment', false
      end

      context 'with multiple scanners having different attributes' do
        let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
        let_it_be(:atomic_policy_rule_multi_scanner) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              { 'type' => 'dependency_scanning', 'vulnerability_attributes' => { 'fix_available' => true } },
              { 'type' => 'sast', 'vulnerability_attributes' => { 'known_exploited' => true } }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[new_needs_triage new_dismissed],
            'vulnerabilities_allowed' => 0
          })
        end

        let!(:report_approver_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            approvals_required: approvals_required,
            scanners: %w[dependency_scanning sast],
            vulnerabilities_allowed: vulnerabilities_allowed,
            severity_levels: severity_levels,
            vulnerability_states: vulnerability_states,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: atomic_policy_rule_multi_scanner
          )
        end

        let(:vulnerabilities_allowed) { 0 }

        before_all do
          Array.new(3) { SecureRandom.uuid }.each do |uuid|
            create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner,
              severity: 'high', uuid: uuid)
          end
        end

        before_all do
          sast_build = create(:ci_build, :success, name: 'sast_1', pipeline: pipeline, project: project)
          create(:security_scan, :succeeded, project: project, build: sast_build, scan_type: 'sast')
          create(:security_scan, :succeeded, project: project, pipeline: target_pipeline, scan_type: 'sast')
        end

        it_behaves_like 'does not update approvals_required'
        it_behaves_like 'triggers policy bot comment', true
      end

      context 'when only some scanner groups violate the policy' do
        let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
        let(:vulnerabilities_allowed) { 0 }

        let_it_be(:atomic_policy_rule_partial_violation) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              { 'type' => 'dependency_scanning', 'vulnerabilities_allowed' => 0 },
              { 'type' => 'sast', 'vulnerabilities_allowed' => 10 }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[new_needs_triage new_dismissed],
            'vulnerabilities_allowed' => 0
          })
        end

        let(:violating_uuids) { Array.new(3) { SecureRandom.uuid } }
        let(:non_violating_uuids) { Array.new(2) { SecureRandom.uuid } }

        let!(:report_approver_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            approvals_required: approvals_required,
            scanners: %w[dependency_scanning sast],
            vulnerabilities_allowed: vulnerabilities_allowed,
            severity_levels: severity_levels,
            vulnerability_states: vulnerability_states,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: atomic_policy_rule_partial_violation
          )
        end

        before do
          violating_group = Security::ScanResultPolicies::GroupedFindingsEvaluator::GroupResult.new(
            uuids: violating_uuids, vulnerabilities_allowed: 0,
            vulnerability_states: %w[new_needs_triage new_dismissed]
          )
          non_violating_group = Security::ScanResultPolicies::GroupedFindingsEvaluator::GroupResult.new(
            uuids: non_violating_uuids, vulnerabilities_allowed: 10,
            vulnerability_states: %w[new_needs_triage new_dismissed]
          )

          source_evaluator = instance_double(Security::ScanResultPolicies::GroupedFindingsEvaluator,
            grouped_results: [violating_group, non_violating_group])
          target_evaluator = instance_double(Security::ScanResultPolicies::GroupedFindingsEvaluator,
            grouped_results: [])

          allow(Security::ScanResultPolicies::GroupedFindingsEvaluator).to receive(:new)
            .and_return(source_evaluator, target_evaluator)
        end

        it 'only includes uuids from the violating scanner group in violation data' do
          execute

          violation_data = last_violation.violation_data
          newly_detected = violation_data.dig('violations', 'scan_finding', 'uuids', 'newly_detected')

          expect(newly_detected).to match_array(violating_uuids)
          expect(newly_detected).not_to include(*non_violating_uuids)
        end

        it_behaves_like 'does not update approvals_required'
      end

      context 'when mixed state group exceeds allowed count via pre-existing vulnerabilities' do
        let(:vulnerability_states) { %w[detected new_needs_triage] }
        let(:vulnerabilities_allowed) { 0 }

        let_it_be(:atomic_policy_rule_exceeded) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              {
                'type' => 'dependency_scanning',
                'vulnerability_attributes' => { 'fix_available' => true }
              }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[detected new_needs_triage],
            'vulnerabilities_allowed' => 0
          })
        end

        let!(:report_approver_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            approvals_required: approvals_required,
            scanners: scanners,
            vulnerabilities_allowed: vulnerabilities_allowed,
            severity_levels: severity_levels,
            vulnerability_states: vulnerability_states,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: atomic_policy_rule_exceeded
          )
        end

        before do
          allow_next_instance_of(Security::ScanResultPolicies::VulnerabilitiesCountService) do |svc|
            allow(svc).to receive(:execute).and_return({ count: 5, exceeded_allowed_count: true })
          end
        end

        it_behaves_like 'does not update approvals_required'
      end

      context 'when mixed state group has only pre-existing states' do
        let(:vulnerability_states) { %w[detected] }
        let(:vulnerabilities_allowed) { 0 }

        let_it_be(:atomic_policy_rule_preexisting_only) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              {
                'type' => 'dependency_scanning',
                'vulnerability_attributes' => { 'fix_available' => true }
              }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[detected],
            'vulnerabilities_allowed' => 0
          })
        end

        let!(:report_approver_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            approvals_required: approvals_required,
            scanners: scanners,
            vulnerabilities_allowed: vulnerabilities_allowed,
            severity_levels: severity_levels,
            vulnerability_states: vulnerability_states,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: atomic_policy_rule_preexisting_only
          )
        end

        before do
          allow_next_instance_of(Security::ScanResultPolicies::VulnerabilitiesCountService) do |svc|
            allow(svc).to receive(:execute).and_return({ count: 3, exceeded_allowed_count: false })
          end
        end

        it 'does not add newly detected count to total' do
          execute

          expect(report_approver_rule.reload.approvals_required).not_to eq(0)
        end
      end

      context 'when pre-existing only states do not include newly detected in total' do
        let(:vulnerability_states) { %w[detected] }
        let(:vulnerabilities_allowed) { 0 }

        let_it_be(:pre_existing_uuids) { Array.new(3) { SecureRandom.uuid } }
        let_it_be(:new_finding_uuid) { SecureRandom.uuid }

        let_it_be(:atomic_policy_rule_preexisting_no_newly_detected) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              {
                'type' => 'dependency_scanning',
                'vulnerability_attributes' => { 'fix_available' => true }
              }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[detected],
            'vulnerabilities_allowed' => 0
          })
        end

        let!(:report_approver_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            approvals_required: approvals_required,
            scanners: scanners,
            vulnerabilities_allowed: vulnerabilities_allowed,
            severity_levels: severity_levels,
            vulnerability_states: vulnerability_states,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: atomic_policy_rule_preexisting_no_newly_detected
          )
        end

        before_all do
          (pre_existing_uuids + [new_finding_uuid]).each do |uuid|
            create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner,
              severity: 'high', uuid: uuid)
          end

          pre_existing_uuids.each do |uuid|
            create(:security_finding, :with_finding_data, scan: target_scan, scanner: scanner,
              severity: 'high', uuid: uuid)
          end
        end

        before do
          allow_next_instance_of(Security::ScanResultPolicies::VulnerabilitiesCountService) do |svc|
            allow(svc).to receive(:execute).and_return({ count: 3, exceeded_allowed_count: false })
          end
        end

        it 'does not include newly detected count in total' do
          execute

          expect(report_approver_rule.reload.approvals_required).not_to eq(0)
        end
      end

      context 'when mixed state group has only pre-existing states and does not exceed allowed' do
        let(:vulnerability_states) { %w[detected new_needs_triage] }
        let(:vulnerabilities_allowed) { 5 }

        let_it_be(:atomic_policy_rule_preexisting_no_exceed) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              { 'type' => 'dependency_scanning', 'vulnerability_attributes' => { 'fix_available' => true } },
              { 'type' => 'sast', 'vulnerability_attributes' => { 'known_exploited' => true } }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[detected new_needs_triage],
            'vulnerabilities_allowed' => 5
          })
        end

        let!(:report_approver_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            approvals_required: approvals_required,
            scanners: %w[dependency_scanning sast],
            vulnerabilities_allowed: vulnerabilities_allowed,
            severity_levels: severity_levels,
            vulnerability_states: vulnerability_states,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: atomic_policy_rule_preexisting_no_exceed
          )
        end

        before do
          pre_existing_uuids = Array.new(3) { SecureRandom.uuid }

          source_preexisting_group = Security::ScanResultPolicies::GroupedFindingsEvaluator::GroupResult.new(
            uuids: pre_existing_uuids, vulnerabilities_allowed: 5, vulnerability_states: %w[detected]
          )
          source_newly_detected_group = Security::ScanResultPolicies::GroupedFindingsEvaluator::GroupResult.new(
            uuids: [SecureRandom.uuid], vulnerabilities_allowed: 5, vulnerability_states: %w[new_needs_triage]
          )
          target_group_result = Security::ScanResultPolicies::GroupedFindingsEvaluator::GroupResult.new(
            uuids: pre_existing_uuids, vulnerabilities_allowed: nil, vulnerability_states: %w[detected]
          )

          source_evaluator = instance_double(Security::ScanResultPolicies::GroupedFindingsEvaluator,
            grouped_results: [source_preexisting_group, source_newly_detected_group])
          target_evaluator = instance_double(Security::ScanResultPolicies::GroupedFindingsEvaluator,
            grouped_results: [target_group_result])

          allow(Security::ScanResultPolicies::GroupedFindingsEvaluator).to receive(:new)
            .and_return(source_evaluator, target_evaluator)

          allow_next_instance_of(Security::ScanResultPolicies::VulnerabilitiesCountService) do |svc|
            allow(svc).to receive(:execute).and_return({ count: 3, exceeded_allowed_count: false })
          end
        end

        it 'does not add newly detected count to total for pre-existing group' do
          execute

          expect(report_approver_rule.reload.approvals_required).to eq(0)
        end
      end

      context 'when mixed state group includes newly detected and does not exceed allowed via pre-existing' do
        let(:vulnerability_states) { %w[detected new_needs_triage] }
        let(:vulnerabilities_allowed) { 0 }
        let(:new_finding_uuids) { Array.new(3) { SecureRandom.uuid } }

        let_it_be(:atomic_policy_rule_mixed_newly_detected) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              { 'type' => 'dependency_scanning', 'vulnerability_attributes' => { 'fix_available' => true } }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[detected new_needs_triage],
            'vulnerabilities_allowed' => 0
          })
        end

        let!(:report_approver_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            approvals_required: approvals_required,
            scanners: scanners,
            vulnerabilities_allowed: vulnerabilities_allowed,
            severity_levels: severity_levels,
            vulnerability_states: vulnerability_states,
            scan_result_policy_read: scan_result_policy_read,
            approval_policy_rule: atomic_policy_rule_mixed_newly_detected
          )
        end

        let(:source_group_result) do
          Security::ScanResultPolicies::GroupedFindingsEvaluator::GroupResult.new(
            uuids: new_finding_uuids,
            vulnerabilities_allowed: nil,
            vulnerability_states: %w[detected new_needs_triage]
          )
        end

        let(:target_group_result) do
          Security::ScanResultPolicies::GroupedFindingsEvaluator::GroupResult.new(
            uuids: [],
            vulnerabilities_allowed: nil,
            vulnerability_states: %w[detected new_needs_triage]
          )
        end

        before do
          source_evaluator = instance_double(Security::ScanResultPolicies::GroupedFindingsEvaluator,
            grouped_results: [source_group_result])
          target_evaluator = instance_double(Security::ScanResultPolicies::GroupedFindingsEvaluator,
            grouped_results: [target_group_result])

          allow(Security::ScanResultPolicies::GroupedFindingsEvaluator).to receive(:new)
            .and_return(source_evaluator, target_evaluator)

          allow_next_instance_of(Security::ScanResultPolicies::VulnerabilitiesCountService) do |svc|
            allow(svc).to receive(:execute).and_return({ count: 0, exceeded_allowed_count: false })
          end
        end

        it 'adds newly detected count to total' do
          execute

          expect(report_approver_rule.reload.approvals_required).not_to eq(0)
        end
      end

      context 'when no target pipeline exists' do
        let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
        let(:vulnerabilities_allowed) { 0 }

        before do
          allow_next_instance_of(described_class) do |svc|
            allow(svc).to receive(:target_pipeline).and_return(nil)
          end

          Array.new(3) { SecureRandom.uuid }.each do |uuid|
            create(:security_finding, :with_finding_data, scan: pipeline_scan, scanner: scanner,
              severity: 'high', uuid: uuid)
          end
        end

        it_behaves_like 'does not update approvals_required'
      end

      context 'when related pipeline ids are blank' do
        let(:vulnerability_states) { %w[new_needs_triage new_dismissed] }
        let(:vulnerabilities_allowed) { 0 }

        before do
          allow_next_instance_of(described_class) do |svc|
            allow(svc).to receive_messages(related_source_pipeline_ids: [], enforce_scans_presence!: false)
          end
        end

        it 'excludes related_pipeline_ids from source evaluator params' do
          allow(Security::ScanResultPolicies::GroupedFindingsEvaluator).to receive(:new)
            .with(anything, target_pipeline, a_kind_of(Hash))
            .and_call_original

          expect(Security::ScanResultPolicies::GroupedFindingsEvaluator).to receive(:new)
            .with(anything, pipeline, hash_not_including(:related_pipeline_ids)).once
            .and_call_original

          execute
        end
      end

      context 'when approval rule has no scan_result_policy_read' do
        let(:vulnerability_states) { %w[detected new_needs_triage] }
        let(:vulnerabilities_allowed) { 0 }

        let_it_be(:atomic_policy_rule_no_policy_read) do
          create(:approval_policy_rule, :scan_finding, content: {
            'type' => 'scan_finding',
            'branches' => [],
            'scanners' => [
              {
                'type' => 'dependency_scanning',
                'vulnerability_attributes' => { 'fix_available' => true }
              }
            ],
            'severity_levels' => %w[high],
            'vulnerability_states' => %w[detected new_needs_triage],
            'vulnerabilities_allowed' => 0
          })
        end

        let!(:report_approver_rule) do
          create(:report_approver_rule, :scan_finding,
            merge_request: merge_request,
            approvals_required: approvals_required,
            scanners: scanners,
            vulnerabilities_allowed: vulnerabilities_allowed,
            severity_levels: severity_levels,
            vulnerability_states: vulnerability_states,
            scan_result_policy_read: nil,
            approval_policy_rule: atomic_policy_rule_no_policy_read
          )
        end

        it 'does not raise an error' do
          expect { execute }.not_to raise_error
        end
      end
    end

    context 'when approval rule has no approval_policy_source' do
      before do
        report_approver_rule.update!(scan_result_policy_read: nil, approval_policy_rule: nil)
      end

      it 'evaluates without error' do
        expect { execute }.not_to raise_error
      end
    end

    context 'when approval rule is backed by approval_policy_rule' do
      include_context 'with approval rule backed by approval_policy_rule'
      include_context 'with divergent vulnerability_age across approval_policy_source'

      let(:approval_policy_source_read) { scan_result_policy_read }
      let(:approval_policy_source_rule) { report_approver_rule }

      it 'queries vulnerabilities using vulnerability_age from approval_policy_rule content' do
        expect(Security::ScanResultPolicies::VulnerabilitiesCountService)
          .to receive(:new)
          .with(hash_including(vulnerability_age: { operator: :greater_than, interval: :day, value: 10 }))
          .at_least(:once).and_call_original

        execute
      end
    end
  end

  describe '#scan_missing?' do
    let(:scanners) { %w[dependency_scanning] }

    let_it_be_with_reload(:project) { create(:project, :repository) }
    let_it_be_with_refind(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:pipeline) do
      create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
        ref: merge_request.source_branch, sha: merge_request.diff_head_sha)
    end

    let_it_be_with_refind(:target_pipeline) do
      create(:ee_ci_pipeline, :success, :with_dependency_scanning_report, project: project,
        ref: merge_request.target_branch, sha: merge_request.diff_base_sha)
    end

    let_it_be_with_refind(:source_scan) do
      create(:security_scan, :succeeded, project: project, pipeline: pipeline, scan_type: 'dependency_scanning')
    end

    let_it_be_with_refind(:target_scan) do
      create(:security_scan, :succeeded,
        project: project,
        pipeline: target_pipeline,
        scan_type: 'dependency_scanning')
    end

    let!(:approval_rule) do
      create(:report_approver_rule, :scan_finding, merge_request: merge_request, scanners: scanners)
    end

    subject(:scan_missing?) do
      described_class.new(merge_request: merge_request, pipeline: pipeline).scan_missing?(approval_rule)
    end

    context 'with both source and target pipeline scans present' do
      it { is_expected.to be(false) }
    end

    context 'with only source pipeline scan' do
      before do
        target_scan.destroy!
      end

      it { is_expected.to be(false) }
    end

    context 'with only target pipeline scan' do
      before do
        source_scan.destroy!
      end

      it { is_expected.to be(true) }
    end

    context 'when not all scanners enforced by the policy are present in the pipeline' do
      let(:scanners) { %w[dependency_scanning container_scanning] }

      # The stricter enforcement could impact existing policies, mainly with `scanners: []`.
      # For now, we don't block. See more in https://gitlab.com/groups/gitlab-org/-/epics/14119.
      it { is_expected.to be(false) }
    end

    context 'without any scans in the source or target pipeline' do
      before do
        target_scan.destroy!
        source_scan.destroy!
      end

      it { is_expected.to be(false) }
    end
  end

  def create_findings_with_vulnerabilities(scan, uuids)
    uuids.each do |uuid|
      create(:security_finding, scan: scan, scanner: scanner, severity: 'high', uuid: uuid)

      vulnerability = create(:vulnerability, project: project)
      create(:vulnerabilities_finding, project: project, scanner: scanner, uuid: uuid, vulnerability: vulnerability)
    end
  end

  describe 'when approval rule has no approval_policy_source' do
    let_it_be_with_reload(:project) { create(:project, :repository) }
    let_it_be(:merge_request) { create(:merge_request, source_project: project) }
    let_it_be(:pipeline) { create(:ee_ci_pipeline, :success, project: project) }

    let_it_be(:rule) do
      create(:report_approver_rule, :scan_finding,
        merge_request: merge_request,
        approvals_required: 1,
        scanners: %w[dependency_scanning],
        scan_result_policy_read: nil,
        approval_policy_rule: nil)
    end

    let(:service) { described_class.new(merge_request: merge_request, pipeline: pipeline) }

    it 'fail_open? returns nil' do
      expect(service.send(:fail_open?, rule)).to be_nil
    end

    it 'vulnerabilities_count_for_uuids handles nil vulnerability_age' do
      expect { service.send(:vulnerabilities_count_for_uuids, [], rule) }.not_to raise_error
    end
  end
end
