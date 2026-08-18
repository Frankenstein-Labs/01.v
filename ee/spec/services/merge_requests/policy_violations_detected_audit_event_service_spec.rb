# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::PolicyViolationsDetectedAuditEventService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:policy_project) { create(:project) }
  let_it_be_with_reload(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: policy_project)
  end

  let_it_be_with_reload(:merge_request) do
    create(:merge_request, title: "Test MR", source_project: project, target_project: project)
  end

  let_it_be(:merge_request_reference) { "#{project.full_path}!#{merge_request.iid}" }
  let_it_be(:security_policy_name) { 'Test Policy' }
  let_it_be_with_reload(:security_policy) do
    create(:security_policy, :approval_policy,
      name: security_policy_name,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:uuid) { SecureRandom.uuid }
  let_it_be(:uuid_previous) { SecureRandom.uuid }

  let(:service) { described_class.new(merge_request) }

  let(:license_violation_data) { { violations: { license_scanning: { 'MIT License' => %w[A B] } } } }
  let(:any_mr_violation_data) { { violations: { any_merge_request: { commits: true } } } }
  let(:scan_finding_violation_data) do
    {
      context: { pipeline_ids: [pipeline.id] },
      violations: { scan_finding: { uuids: { newly_detected: [uuid], previously_existing: [uuid_previous] } } }
    }
  end

  def create_policy_read
    create(:scan_result_policy_read, project: project,
      security_orchestration_policy_configuration: policy_configuration)
  end

  def create_violation(policy, rule, data = {}, status = :failed)
    create(:scan_result_policy_violation, status,
      project: project,
      merge_request: merge_request,
      scan_result_policy_read: policy,
      approval_policy_rule: rule,
      violation_data: data
    )
  end

  def create_error_violation(policy, rule, error, status = :failed, **extra)
    create_violation(policy, rule, { 'errors' => [{ 'error' => error, **extra }] }, status)
  end

  describe '#execute' do
    subject(:execute_service) { service.execute }

    let(:audit_context) do
      {
        name: 'security_policy_violations_detected',
        author: merge_request.author,
        scope: policy_project,
        target: security_policy,
        message: "Security policy violation(s) is detected in merge request (#{merge_request_reference})",
        additional_details: {
          merge_request_title: merge_request.title,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          source_branch: merge_request.source_branch,
          target_branch: merge_request.target_branch,
          project_id: project.id,
          project_name: project.name,
          project_full_path: project.full_path,
          policy_violations: [policy_violation]
        }
      }
    end

    let(:policy_violation) do
      {
        approval_policy_rule_id: Security::ApprovalPolicyRule.last.id,
        violation_status: violation_status,
        violation_data: violation_data.as_json
      }
    end

    shared_examples 'recording the audit event' do
      it 'records a security_policy_violations_detected audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

        execute_service
      end
    end

    shared_examples 'not recording the audit event' do
      it 'does not record a security_policy_violations_detected audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(anything)

        execute_service
      end
    end

    context 'when there are scan finding violations' do
      let_it_be(:policy) { create_policy_read }
      let_it_be(:approver_rule_policy) do
        create(:report_approver_rule, :scan_finding, name: security_policy_name,
          merge_request: merge_request, scan_result_policy_read: policy)
      end

      let_it_be(:pipeline) do
        create(:ee_ci_pipeline, :with_dependency_scanning_report, :success, project: project,
          ref: merge_request.source_branch, sha: merge_request.diff_head_sha,
          merge_requests_as_head_pipeline: [merge_request])
      end

      let(:violation_status) { 'failed' }
      let(:violation_data) { scan_finding_violation_data }

      before do
        approval_rule = create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
        create_violation(policy, approval_rule, violation_data)
      end

      it_behaves_like 'recording the audit event'
    end

    context 'when there are any merge request violations' do
      let(:violation_status) { 'failed' }
      let(:violation_data) { any_mr_violation_data }

      before do
        approval_rule = create(:approval_policy_rule, :any_merge_request, security_policy: security_policy)
        create_violation(create_policy_read, approval_rule, violation_data)
      end

      it_behaves_like 'recording the audit event'
    end

    context 'when there are license scanning violations' do
      let(:violation_status) { 'failed' }
      let(:violation_data) { license_violation_data }

      before do
        approval_rule = create(:approval_policy_rule, :license_finding, security_policy: security_policy)
        create_violation(create_policy_read, approval_rule, violation_data)
      end

      it_behaves_like 'recording the audit event'
    end

    context 'when there are multiple violations' do
      let(:license_approval_rule) { create(:approval_policy_rule, :license_finding, security_policy: security_policy) }
      let(:any_mr_approval_rule) { create(:approval_policy_rule, :any_merge_request, security_policy: security_policy) }

      let(:policy_violations) do
        [
          {
            approval_policy_rule_id: license_approval_rule.id,
            violation_status: 'failed',
            violation_data: license_violation_data.as_json
          },
          {
            approval_policy_rule_id: any_mr_approval_rule.id,
            violation_status: 'failed',
            violation_data: any_mr_violation_data.as_json
          }
        ]
      end

      before do
        create_violation(create_policy_read, license_approval_rule, license_violation_data)
        create_violation(create_policy_read, any_mr_approval_rule, any_mr_violation_data)
      end

      context 'when violations are from the same policy' do
        it 'groups the violations and record one audit event for the policy' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).once.with(
            a_hash_including(additional_details: hash_including(policy_violations: policy_violations))
          )
          execute_service
        end
      end

      context 'when there are multiple violations from different policies' do
        let!(:another_security_policy) do
          create(:security_policy, :approval_policy, name: 'Another Policy',
            policy_index: 1, security_orchestration_policy_configuration: policy_configuration)
        end

        let!(:another_license_rule) do
          create(:approval_policy_rule, :license_finding, security_policy: another_security_policy)
        end

        let(:other_policy_violations) do
          [{
            approval_policy_rule_id: another_license_rule.id,
            violation_status: 'failed',
            violation_data: license_violation_data.as_json
          }]
        end

        before do
          create(:report_approver_rule, :license_scanning, name: 'Another License Approval Rule',
            merge_request: merge_request.reload, approval_policy_rule: another_license_rule,
            approvals_required: 1, user_ids: [create(:user).id])

          create_violation(create_policy_read, another_license_rule, license_violation_data)
        end

        it 'records two audit events for the two policies' do
          [policy_violations, other_policy_violations].each do |violations|
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
              a_hash_including(additional_details: hash_including(policy_violations: violations))
            )
          end

          execute_service
        end
      end
    end

    context 'when there are errors' do
      let_it_be(:policy) { create_policy_read }

      let(:violation_status) { 'failed' }
      let(:violation_data) { { 'errors' => [{ 'error' => 'SCAN_REMOVED', 'missing_scans' => %w[sast] }] } }

      before do
        approval_rule = create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
        create_error_violation(policy, approval_rule, 'SCAN_REMOVED', 'missing_scans' => %w[sast])
      end

      it_behaves_like 'recording the audit event'
    end

    context 'when there are running violations' do
      let_it_be(:policy) { create_policy_read }

      let_it_be(:running_violation) do
        approval_rule = create(:approval_policy_rule, :scan_finding, security_policy: security_policy)
        create_violation(policy, approval_rule, {}, :running)
      end

      it_behaves_like 'not recording the audit event'
    end

    context 'when there are no violations' do
      it_behaves_like 'not recording the audit event'
    end
  end
end
