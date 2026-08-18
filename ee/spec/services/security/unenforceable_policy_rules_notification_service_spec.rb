# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::UnenforceablePolicyRulesNotificationService, '#execute', feature_category: :security_policy_management do
  let_it_be(:newly_detected_policy_content) do
    {
      type: 'scan_finding', branches: [], scanners: %w[dependency_scanning], vulnerabilities_allowed: 0,
      severity_levels: %w[critical], vulnerability_states: %w[detected],
      license_states: %w[newly_detected], match_on_inclusion_license: true
    }
  end

  let_it_be(:project, freeze: false) { create(:project, :repository) }

  let(:service) { described_class.new(merge_request) }

  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be_with_reload(:pipeline) do
    create(:ee_ci_pipeline,
      :success,
      project: project,
      ref: merge_request.source_branch,
      sha: project.commit(merge_request.source_branch).sha,
      merge_requests_as_head_pipeline: [merge_request]
    )
  end

  let_it_be_with_reload(:scan_result_policy_read) do
    create(:scan_result_policy_read, project: project, license_states: %w[newly_detected])
  end

  let_it_be(:protected_branch, freeze: false) do
    create(:protected_branch, name: merge_request.target_branch, project: project)
  end

  subject(:execute) { service.execute }

  before do
    stub_licensed_features(security_orchestration_policies: true, dependency_scanning: true)
  end

  shared_examples_for 'does not block enforceable rules' do
    let_it_be_with_reload(:approval_scan_finding_rule) { create_approval_rule(:scan_finding, approvals_required: 0) }
    let_it_be_with_reload(:approval_license_scanning_rule) do
      create_approval_rule(:license_scanning, approvals_required: 0)
    end

    it_behaves_like 'does not trigger policy bot comment'

    it 'does not reset approvals', :aggregate_failures do
      execute

      expect(approval_scan_finding_rule.reload.approvals_required).to eq 0
      expect(approval_license_scanning_rule.reload.approvals_required).to eq 0
    end
  end

  shared_examples_for 'blocks newly detected unenforceable approval rules' do
  |unenforceable_reports = %i[scan_finding license_scanning]|
    context 'without approval rules' do
      it_behaves_like 'does not trigger policy bot comment'
    end

    context 'with approval rules' do
      context 'when approval rules target newly_detected states' do
        let_it_be_with_reload(:approval_scan_finding_rule) { create_approval_rule(:scan_finding) }
        let_it_be_with_reload(:approval_license_scanning_rule) { create_approval_rule(:license_scanning) }

        it 'enqueues Security::GeneratePolicyViolationCommentWorker for unenforceable report types' do
          expect(Security::GeneratePolicyViolationCommentWorker)
            .to receive(:perform_async).exactly(unenforceable_reports.size).with(merge_request.id)

          execute
        end

        it 'resets approvals', :aggregate_failures do
          execute

          expect(approval_scan_finding_rule.reload.approvals_required).to eq 1
          expect(approval_license_scanning_rule.reload.approvals_required).to eq 1
        end
      end

      context 'when approval rules target only pre-existing states' do
        before do
          scan_result_policy_read.update!(license_states: %w[detected])
        end

        let_it_be_with_reload(:approval_scan_finding_rule) do
          create_approval_rule(:scan_finding, vulnerability_states: %w[detected], approvals_required: 0)
        end

        let_it_be_with_reload(:approval_license_scanning_rule) do
          create_approval_rule(:license_scanning, approvals_required: 0)
        end

        it_behaves_like 'does not trigger policy bot comment'

        it 'does not reset approvals', :aggregate_failures do
          execute

          expect(approval_scan_finding_rule.reload.approvals_required).to eq 0
          expect(approval_license_scanning_rule.reload.approvals_required).to eq 0
        end
      end
    end
  end

  context 'without report approver rules' do
    it_behaves_like 'does not trigger policy bot comment'

    it 'does not log message' do
      expect(Gitlab::AppJsonLogger).not_to receive(:info)

      execute
    end
  end

  context 'when all reports are enforceable' do
    before_all do
      create(:ee_ci_build, :sast, pipeline: pipeline, project: project)
      create(:ee_ci_build, :cyclonedx, pipeline: pipeline, project: pipeline.project)
    end

    it_behaves_like 'does not block enforceable rules'

    it 'logs the corresponding message' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(message: 'No unenforceable scan_finding rules detected, skipping'))
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(message: 'No unenforceable license_scanning rules detected, skipping'))

      execute
    end
  end

  context 'when merge request has no head pipeline' do
    before do
      merge_request.update!(head_pipeline: nil)
    end

    it_behaves_like 'blocks newly detected unenforceable approval rules'
  end

  context 'when pipeline creation is pending' do
    let_it_be(:fail_open_policy) do
      create(:scan_result_policy_read, :fail_open, project: project, license_states: %w[newly_detected])
    end

    let_it_be(:fail_open_rule) do
      create(:report_approver_rule, :scan_finding, merge_request: merge_request,
        approvals_required: 1, scan_result_policy_read: fail_open_policy)
    end

    shared_examples 'defers evaluation without unblocking' do
      it 'does not unblock fail-open rules' do
        expect { execute }.not_to change { fail_open_rule.reload.approvals_required }
      end

      it 'logs the deferral message' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(message: 'Pipeline pending or in creation, deferring evaluation'))

        execute
      end
    end

    context 'when pipeline is still active' do
      before do
        pipeline.update!(status: :running)
      end

      it_behaves_like 'defers evaluation without unblocking'
    end

    context 'when pipeline is in created state' do
      before do
        pipeline.update!(status: :created)
      end

      it_behaves_like 'defers evaluation without unblocking'
    end

    context 'when pipeline is canceling' do
      before do
        pipeline.update!(status: :canceling)
      end

      it_behaves_like 'defers evaluation without unblocking'
    end

    context 'when async pipeline creation is in progress' do
      before do
        merge_request.update!(head_pipeline: nil)
        allow(merge_request).to receive(:pipeline_creating?).and_return(true)
      end

      it_behaves_like 'defers evaluation without unblocking'
    end
  end

  context 'when merge request has multiple pipelines for diff_head_sha' do
    let_it_be(:merge_request_pipeline) do
      create(:ee_ci_pipeline,
        :success,
        project: project,
        ref: merge_request.source_branch,
        sha: project.commit(merge_request.source_branch).sha
      )
    end

    context 'when there are no security reports' do
      it_behaves_like 'blocks newly detected unenforceable approval rules'
    end

    context 'when there are security reports for non head pipeline' do
      before_all do
        create(:ee_ci_build, :sast, pipeline: merge_request_pipeline, project: project)
        create(:ee_ci_build, :cyclonedx, pipeline: merge_request_pipeline, project: project)
      end

      it_behaves_like 'does not block enforceable rules'
    end
  end

  shared_examples_for 'unenforceable report' do |report_type|
    it_behaves_like 'blocks newly detected unenforceable approval rules',
      report_type == :scan_finding ? %i[scan_finding license_scanning] : %i[license_scanning]

    context 'with violated approval rules' do
      let(:approvals_required) { 1 }

      let_it_be(:violated_approval_policy_rule) do
        config = scan_result_policy_read.security_orchestration_policy_configuration
        create(:approval_policy_rule, :scan_finding, content: newly_detected_policy_content,
          security_policy: create(:security_policy, :approval_policy,
            security_orchestration_policy_configuration: config))
      end

      let!(:approval_project_rule) do
        create(:approval_project_rule, :any_merge_request, project: project, approvals_required: approvals_required,
          applies_to_all_protected_branches: true, protected_branches: [protected_branch],
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: violated_approval_policy_rule)
      end

      let_it_be_with_reload(:violation) do
        create(:scan_result_policy_violation, :running, merge_request: merge_request,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: violated_approval_policy_rule, project: project)
      end

      before do
        create(:report_approver_rule, report_type, merge_request: merge_request,
          approval_project_rule: approval_project_rule, approvals_required: approvals_required,
          scan_result_policy_read: scan_result_policy_read,
          approval_policy_rule: violated_approval_policy_rule)
      end

      it_behaves_like 'triggers policy bot comment', true

      it 'logs the corresponding message' do
        allow(Gitlab::AppJsonLogger).to receive(:info)
        expect(Gitlab::AppJsonLogger).to receive(:info).with(hash_including(
          event: 'unenforceable_rules',
          message: "Unenforceable #{report_type} rules detected"
        ))

        execute
      end

      it 'updates violation status' do
        expect { execute }.to change { violation.reload.status }.from('running').to('failed')
      end

      it 'updates violation data' do
        expect { execute }.to change { violation.reload.violation_data }
          .to match(a_hash_including({ 'errors' => ['error' => 'ARTIFACTS_MISSING'] }))
      end

      context 'when pipeline failed' do
        before do
          pipeline.update!(status: :failed)
        end

        it 'updates violation error' do
          expect { execute }.to change { violation.reload.status }.from('running').to('failed')
        end

        it 'updates violation data' do
          expect { execute }.to change { violation.reload.violation_data }
            .to match(a_hash_including({ 'errors' => ['error' => 'PIPELINE_FAILED'] }))
        end
      end

      context 'without required approvals' do
        let(:approvals_required) { 0 }

        it_behaves_like 'triggers policy bot comment', true
      end

      context 'when approval rules are not applicable to the target branch' do
        let_it_be(:policy_project) { create(:project, :repository) }
        let_it_be(:policy_configuration) do
          create(:security_orchestration_policy_configuration,
            project: project,
            security_policy_management_project: policy_project)
        end

        let(:approval_policy) { build(:approval_policy, :any_merge_request, branches: ['protected']) }
        let(:policy_yaml) do
          build(:orchestration_policy_yaml, approval_policy: [approval_policy])
        end

        before do
          merge_request.update!(target_branch: 'non-protected')
          allow_next_instance_of(Repository) do |repository|
            allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
          end
        end

        it_behaves_like 'triggers policy bot comment', false

        it 'removes violations' do
          expect { execute }.to change { Security::ScanResultPolicyViolation.exists?(violation.id) }
                                  .from(true).to(false)
        end
      end
    end

    describe 'fail-closed rules' do
      let_it_be(:closed_scan_result_policy_read) do
        create(:scan_result_policy_read, :fail_closed, project: project, license_states: %w[newly_detected])
      end

      let_it_be(:approval_project_rule) do
        create(:approval_project_rule, :any_merge_request, project: project, approvals_required: 2,
          applies_to_all_protected_branches: true, protected_branches: [protected_branch],
          scan_result_policy_read: closed_scan_result_policy_read)
      end

      let_it_be_with_reload(:fail_closed_rule) do
        create(
          :report_approver_rule,
          report_type,
          name: "#{report_type} Fail Closed",
          merge_request: merge_request,
          approvals_required: 1,
          scan_result_policy_read: closed_scan_result_policy_read,
          approval_project_rule: approval_project_rule)
      end

      it 'resets the approvals required to the source rule' do
        expect { subject }.to change { fail_closed_rule.reload.approvals_required }.from(1).to(2)
      end
    end

    describe 'fail-open rules' do
      let_it_be_with_reload(:fail_open_policy) do
        create(:scan_result_policy_read, :fail_open, project: project, license_states: %w[newly_detected])
      end

      let_it_be(:fail_open_policy_rule) do
        config = fail_open_policy.security_orchestration_policy_configuration
        create(:approval_policy_rule, :scan_finding, content: newly_detected_policy_content,
          security_policy: create(:security_policy, :approval_policy, content: { fallback_behavior: { fail: 'open' } },
            security_orchestration_policy_configuration: config))
      end

      let_it_be_with_reload(:fail_open_rule) do
        create(
          :report_approver_rule,
          report_type,
          name: "#{report_type} Fail Open",
          merge_request: merge_request,
          approvals_required: 1,
          scan_result_policy_read: fail_open_policy,
          approval_policy_rule: fail_open_policy_rule)
      end

      let_it_be_with_reload(:fail_closed_policy) do
        create(:scan_result_policy_read, project: project, license_states: %w[newly_detected])
      end

      let_it_be(:fail_closed_policy_rule) do
        config = fail_closed_policy.security_orchestration_policy_configuration
        create(:approval_policy_rule, :scan_finding, content: newly_detected_policy_content,
          security_policy: create(:security_policy, :approval_policy,
            security_orchestration_policy_configuration: config))
      end

      let!(:fail_closed_rule) do
        create(
          :report_approver_rule,
          report_type,
          name: "#{report_type} Fail Closed",
          merge_request: merge_request,
          approvals_required: 1,
          scan_result_policy_read: fail_closed_policy,
          approval_policy_rule: fail_closed_policy_rule)
      end

      it "unblocks fail-open rules" do
        expect { subject }.to change { fail_open_rule.reload.approvals_required }
        .and not_change { fail_closed_rule.reload.approvals_required }
      end

      it "persists the violations", :aggregate_failures do
        expect { subject }.to change { merge_request.scan_result_policy_violations.count }.by(2)
        expect(merge_request.scan_result_policy_violations.map(&:status)).to contain_exactly('warn', 'failed')
      end

      it_behaves_like 'triggers policy bot comment', true

      context "when all rules fail open" do
        let(:fail_closed_rule) { nil }

        it_behaves_like 'triggers policy bot comment', true

        it 'updates violation status' do
          execute
          expect(merge_request.scan_result_policy_violations).to all(be_warn)
        end
      end

      context "without persisted policy" do
        before do
          fail_closed_rule.scan_result_policy_read.delete
        end

        it "does not raise" do
          expect { subject }.not_to raise_error
        end
      end
    end
  end

  shared_context 'with unenforceable rules unblocked by scan execution policy' do |_report_type, _other_report_type|
    let_it_be(:approval_project_rule) do
      create(:approval_project_rule, :scan_finding, project: project, approvals_required: 1,
        applies_to_all_protected_branches: true, protected_branches: [protected_branch],
        scan_result_policy_read: scan_result_policy_read)
    end

    let(:policy_scans) { %w[dependency_scanning container_scanning] }
    let(:scan_execution_policy) { build(:scan_execution_policy, actions: policy_scans.map { |scan| { scan: scan } }) }

    let(:unblock_enabled) { true }
    let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [scan_execution_policy]) }
    let_it_be(:security_orchestration_policy_configuration) do
      create(:security_orchestration_policy_configuration, project: project)
    end

    before do
      scan_result_policy_read.update!(policy_tuning: { unblock_rules_using_execution_policies: unblock_enabled })
      create(:scan_result_policy_violation, merge_request: merge_request,
        scan_result_policy_read: scan_result_policy_read, project: project)

      allow_next_instance_of(Repository) do |repository|
        allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
      end
    end

    context 'when toggle "unblock_rules_using_execution_policies" is disabled' do
      let(:unblock_enabled) { false }

      it 'does not unblock the rules' do
        expect { execute }.not_to change { matching_scanner_rule.reload.approvals_required }
      end
    end
  end

  context 'with unenforceable scan_finding report' do
    before_all do
      create(:ee_ci_build, :requirements_report, pipeline: pipeline, project: pipeline.project)
    end

    it_behaves_like 'unenforceable report', :scan_finding

    context 'with active scan execution policy' do
      include_context 'with unenforceable rules unblocked by scan execution policy'

      let(:vulnerability_states) { %w[new_needs_triage newly_detected] }

      let!(:matching_scanner_rule) do
        create(:report_approver_rule, :scan_finding, name: "Rule matching", merge_request: merge_request,
          approval_project_rule: approval_project_rule, approvals_required: 1,
          vulnerability_states: vulnerability_states,
          scanners: %w[dependency_scanning container_scanning],
          scan_result_policy_read: scan_result_policy_read)
      end

      let_it_be_with_reload(:non_matching_scanner_rule) do
        create(:report_approver_rule, :license_scanning, name: "Rule non matching", merge_request: merge_request,
          approval_project_rule: approval_project_rule, approvals_required: 1,
          scan_result_policy_read: scan_result_policy_read)
      end

      it 'unblocks the rules with matching scanners' do
        expect { execute }.to change { matching_scanner_rule.reload.approvals_required }
          .and change { non_matching_scanner_rule.reload.approvals_required }
      end

      context 'when rule is not excludable' do
        let(:vulnerability_states) { %w[detected] }

        it 'does not unblock the rule' do
          expect { execute }.not_to change { matching_scanner_rule.reload.approvals_required }
        end
      end

      context 'when scan execution policies do not include all scanners' do
        let(:policy_scans) { ['dependency_scanning'] }

        it 'does not unblock the rule' do
          expect { execute }.not_to change { matching_scanner_rule.reload.approvals_required }
        end
      end
    end
  end

  context 'with unenforceable license_scanning report' do
    before_all do
      create(:ee_ci_build, :sast, pipeline: pipeline, project: project)
    end

    it_behaves_like 'unenforceable report', :license_scanning

    context 'with active scan execution policy' do
      include_context 'with unenforceable rules unblocked by scan execution policy'

      let_it_be_with_reload(:matching_scanner_rule) do
        create(:report_approver_rule, :license_scanning, name: "Rule matching", merge_request: merge_request,
          approval_project_rule: approval_project_rule, approvals_required: 1,
          scan_result_policy_read: scan_result_policy_read)
      end

      let_it_be_with_reload(:non_matching_scanner_rule) do
        create(:report_approver_rule, :scan_finding, name: "Rule non matching", merge_request: merge_request,
          approval_project_rule: approval_project_rule, approvals_required: 1,
          scan_result_policy_read: scan_result_policy_read)
      end

      let(:license_states) { %w[newly_detected] }

      before do
        scan_result_policy_read.update!(license_states: license_states)
      end

      it 'unblocks the rules with matching scanners' do
        expect { execute }.to change { matching_scanner_rule.reload.approvals_required }
          .and not_change { non_matching_scanner_rule.reload.approvals_required }
      end

      context 'when rule is not excludable' do
        let(:license_states) { %w[detected] }

        it 'does not unblock the rule' do
          expect { execute }.not_to change { matching_scanner_rule.reload.approvals_required }
        end
      end

      context 'when scan execution policies do not include dependency_scanning' do
        let(:policy_scans) { ['container_scanning'] }

        it 'does not unblock the rule' do
          expect { execute }.not_to change { matching_scanner_rule.reload.approvals_required }
        end
      end
    end
  end

  private

  def create_approval_rule(report_type, vulnerability_states: [], approvals_required: 1)
    project_rule = create(:approval_project_rule, report_type, project: project,
      approvals_required: 1, vulnerability_states: vulnerability_states,
      applies_to_all_protected_branches: true, protected_branches: [protected_branch],
      scan_result_policy_read: scan_result_policy_read)

    create(:report_approver_rule, report_type, merge_request: merge_request, approvals_required: approvals_required,
      vulnerability_states: vulnerability_states,
      scan_result_policy_read: scan_result_policy_read, approval_project_rule: project_rule)
  end
end
