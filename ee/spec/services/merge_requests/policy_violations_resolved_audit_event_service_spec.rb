# frozen_string_literal: true

# spec/services/merge_requests/policy_violations_resolved_audit_event_service_spec.rb
require 'spec_helper'

RSpec.describe MergeRequests::PolicyViolationsResolvedAuditEventService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project, name: 'SP Test') }
  let_it_be(:policy_project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: policy_project)
  end

  let_it_be(:security_policy) do
    create(:security_policy, :approval_policy,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be_with_reload(:merge_request) do
    create(:merge_request, title: "Test MR", source_project: project, target_project: project)
  end

  let(:service) { described_class.new(merge_request) }

  describe '#execute' do
    subject(:execute_service) { service.execute }

    let(:audit_context) do
      {
        name: 'security_policy_violations_resolved',
        author: merge_request.author,
        scope: project,
        target: merge_request,
        message: "All merge request approval policy violation(s) resolved in merge request " \
          "with title 'Test MR'",
        additional_details: {
          merge_request_title: merge_request.title,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          source_branch: merge_request.source_branch,
          target_branch: merge_request.target_branch,
          project_id: project.id,
          project_name: project.name,
          project_full_path: project.full_path
        }
      }
    end

    context 'when there are no existing violations' do
      it 'records a security_policy_violations_detected audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

        execute_service
      end
    end

    context 'when there are existing violations' do
      before do
        approval_policy_rule = create(:approval_policy_rule, :license_finding, security_policy: security_policy)

        policy_read = create(:scan_result_policy_read, project: project,
          security_orchestration_policy_configuration: policy_configuration)

        create(:report_approver_rule, :license_scanning, merge_request: merge_request,
          scan_result_policy_read: policy_read)

        create(:scan_result_policy_violation, :failed, project: project, merge_request: merge_request,
          scan_result_policy_read: policy_read, approval_policy_rule: approval_policy_rule)
      end

      it 'does not record a security_policy_violations_detected audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(anything)

        execute_service
      end
    end
  end
end
