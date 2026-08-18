# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::MergedWithPolicyViolationsAuditEventService, feature_category: :security_policy_management do
  let_it_be(:merger) { create :user }
  let_it_be(:approver) { create :user, username: 'approver one' }
  let_it_be(:mr_author) { create :user, username: 'author one' }
  let_it_be(:project) { create :project, :repository }
  let_it_be(:merge_time) { Time.now.utc }
  let_it_be_with_reload(:merge_request) do
    create :merge_request,
      :opened,
      title: 'MR One',
      description: 'This was a triumph',
      author: mr_author,
      source_project: project,
      target_project: project
  end

  let(:merge_request_reference) { "#{project.full_path}!#{merge_request.iid}" }

  let_it_be(:group) { create(:group) }
  let_it_be(:policy_project) { create(:project, group: group) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: policy_project)
  end

  let_it_be(:security_policy_name) { 'Test Policy' }
  let_it_be(:security_policy) do
    create(:security_policy, :approval_policy,
      name: security_policy_name,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:license_violation_data) { { violations: { license_scanning: { 'MIT License' => %w[A B] } } } }
  let_it_be(:any_mr_violation_data) { { violations: { any_merge_request: { commits: true } } } }

  let(:service) { described_class.new(merge_request) }

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

  describe '#execute' do
    let(:execute_service) { service.execute }

    let(:audit_context) do
      {
        name: 'security_policy_merge_request_merged_with_policy_violations',
        author: merger,
        scope: policy_project,
        target: security_policy,
        message: "Merge request (#{merge_request_reference}) was merged with security policy violation(s)",
        additional_details: {
          merge_request_title: merge_request.title,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          merged_at: merge_request.merged_at,
          source_branch: merge_request.source_branch,
          target_branch: merge_request.target_branch,
          project_id: project.id,
          project_name: project.name,
          project_full_path: project.full_path,
          policy_violations: policy_violations,
          policy_approval_rules: policy_approval_rules
        }
      }
    end

    shared_examples 'not recording the audit event' do
      it 'does not record a security_policy_merge_request_merged_with_policy_violations audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(anything)

        execute_service
      end
    end

    context 'when merge request is merged' do
      context 'with multiple scan result policy violations' do
        let_it_be(:license_approval_policy_rule) do
          create(:approval_policy_rule, :license_finding, security_policy: security_policy)
        end

        let_it_be(:any_mr_approval_policy_rule) do
          create(:approval_policy_rule, :any_merge_request, security_policy: security_policy)
        end

        let_it_be(:license_approval_rule) do
          create(
            :report_approver_rule,
            :license_scanning,
            merge_request: merge_request.reload,
            approval_policy_rule: license_approval_policy_rule,
            approvals_required: 1,
            user_ids: [approver.id]
          )
        end

        let_it_be(:any_mr_approval_rule) do
          create(
            :report_approver_rule,
            :any_merge_request,
            merge_request: merge_request.reload,
            approval_policy_rule: any_mr_approval_policy_rule,
            approvals_required: 1,
            user_ids: [approver.id]
          )
        end

        let(:policy_approval_rules) do
          [
            {
              name: security_policy_name,
              report_type: 'license_scanning',
              approved: true,
              approvals_required: 1,
              approved_approvers: ['approver one'],
              invalid_rule: false,
              fail_open: false
            },
            {
              name: security_policy_name,
              report_type: 'any_merge_request',
              approved: false,
              approvals_required: 1,
              approved_approvers: [],
              invalid_rule: false,
              fail_open: false
            }
          ]
        end

        let(:policy_violations) do
          [
            {
              approval_policy_rule_id: license_approval_policy_rule.id,
              violation_status: 'failed',
              violation_data: license_violation_data.as_json
            },
            {
              approval_policy_rule_id: any_mr_approval_policy_rule.id,
              violation_status: 'failed',
              violation_data: any_mr_violation_data.as_json
            }
          ]
        end

        before_all do
          create_violation(create_policy_read, license_approval_policy_rule, license_violation_data)

          create(:approval_merge_request_rules_approved_approver,
            approval_merge_request_rule: license_approval_rule, user: approver)

          create_violation(create_policy_read, any_mr_approval_policy_rule, any_mr_violation_data)

          # extra approval rule to ensure policy rules are grouped correctly
          create(:report_approver_rule, :license_scanning, user_ids: [approver.id],
            approval_policy_rule: any_mr_approval_policy_rule, approvals_required: 1)

          merge_request.update!(state_id: MergeRequest.available_states[:merged])
          merge_request.metrics.update!(merged_at: merge_time, merged_by: merger)
        end

        context 'when violations are from the same policy' do
          it 'records one audit event for the policy violations' do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).once.with(audit_context)

            execute_service
          end
        end

        context 'when there violations from different policy' do
          let(:another_policy_approval_rules) do
            [
              {
                name: 'Another Policy',
                report_type: 'license_scanning',
                approved: false,
                approvals_required: 1,
                approved_approvers: [],
                invalid_rule: false,
                fail_open: false
              }
            ]
          end

          before do
            merge_request.update_columns(state_id: MergeRequest.available_states[:opened])

            another_security_policy = create(:security_policy, :approval_policy, name: 'Another Policy',
              policy_index: 1, security_orchestration_policy_configuration_id: policy_configuration.id)

            another_license_approval_policy_rule = create(:approval_policy_rule, :license_finding,
              security_policy: another_security_policy)

            create(:report_approver_rule, :license_scanning,
              name: 'Another License Approval Rule',
              merge_request: merge_request.reload,
              approval_policy_rule: another_license_approval_policy_rule,
              approvals_required: 1,
              user_ids: [approver.id]
            )

            create_violation(create_policy_read, another_license_approval_policy_rule, license_violation_data)

            merge_request.update_columns(state_id: MergeRequest.available_states[:merged])
          end

          it 'records two audit events for the two policies' do
            [policy_approval_rules, another_policy_approval_rules].each do |approval_rules|
              expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
                a_hash_including(additional_details: hash_including(policy_approval_rules: approval_rules)))
            end

            execute_service
          end
        end

        context 'when merged by author is not available' do
          before do
            merge_request.metrics.update!(merged_by: nil)
          end

          it 'audits with a deleted author' do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
              a_hash_including(
                author: an_instance_of(Gitlab::Audit::DeletedAuthor)
              )
            )

            execute_service
          end
        end
      end

      context 'without scan result policy violations' do
        before do
          merge_request.update!(state_id: MergeRequest.available_states[:merged])
        end

        it_behaves_like 'not recording the audit event'
      end
    end

    context 'when merge request is not merged' do
      before do
        merge_request.update!(state_id: MergeRequest.available_states[:closed])
      end

      it_behaves_like 'not recording the audit event'
    end
  end
end
