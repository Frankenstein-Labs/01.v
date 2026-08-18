# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::BasePolicyViolationsAuditEventService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, id: 19212) }
  let_it_be(:merge_request) { create(:merge_request, author: user, source_project: project, target_project: project) }
  let_it_be(:policy_project) { create(:project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project,
      security_policy_management_project: policy_project)
  end

  let_it_be(:security_policy) do
    create(:security_policy, :approval_policy,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let(:license_violation_data) { { violations: { license_scanning: { 'MIT License' => %w[A B] } } } }
  let(:any_mr_violation_data) { { violations: { any_merge_request: { commits: true } } } }

  let(:service_class) do
    Class.new(described_class) do
      def eligible_to_run?
        true
      end

      def audit_event_name
        'test_event'
      end

      def audit_message
        'Test message'
      end

      def audit_author
        merge_request.author
      end
    end
  end

  subject(:service) { service_class.new(merge_request) }

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

    context 'when not eligible to run' do
      before do
        allow(service).to receive(:eligible_to_run?).and_return(false)
      end

      it 'does not audit' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute_service
      end
    end

    context 'when there are no violations' do
      it 'does not audit' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute_service
      end
    end

    context 'when eligible and there are violations' do
      let_it_be(:any_mr_approval_rule) { create(:approval_policy_rule, security_policy: security_policy) }

      before do
        allow(service).to receive(:eligible_to_run?).and_return(true)
        allow(service).to receive(:violations).and_call_original

        create_violation(create_policy_read, any_mr_approval_rule, any_mr_violation_data)
      end

      it 'audits with audit details including the violation details' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with({
          name: 'test_event',
          author: user,
          scope: policy_project,
          target: security_policy,
          message: 'Test message',
          additional_details: {
            merge_request_title: merge_request.title,
            merge_request_id: merge_request.id,
            merge_request_iid: merge_request.iid,
            source_branch: merge_request.source_branch,
            target_branch: merge_request.target_branch,
            project_id: project.id,
            project_name: project.name,
            project_full_path: project.full_path,
            policy_violations: [
              {
                approval_policy_rule_id: any_mr_approval_rule.id,
                violation_status: 'failed',
                violation_data: any_mr_violation_data.as_json
              }
            ]
          }
        })

        execute_service
      end

      context 'when there are multiple violations' do
        let(:license_approval_rule) do
          create(:approval_policy_rule, :license_finding, security_policy: security_policy)
        end

        let(:policy_violations) do
          [
            {
              approval_policy_rule_id: any_mr_approval_rule.id,
              violation_status: 'failed',
              violation_data: any_mr_violation_data.as_json
            },
            {
              approval_policy_rule_id: license_approval_rule.id,
              violation_status: 'failed',
              violation_data: license_violation_data.as_json
            }
          ]
        end

        before do
          create_violation(create_policy_read, license_approval_rule, license_violation_data)
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
    end
  end

  describe 'abstract methods' do
    let(:abstract_service) { described_class.new(merge_request) }

    it 'raises NoMethodError for eligible_to_run?' do
      expect { abstract_service.send(:eligible_to_run?) }.to raise_error(NoMethodError)
    end

    it 'raises NoMethodError for audit_event_name' do
      expect { abstract_service.send(:audit_event_name) }.to raise_error(NoMethodError)
    end

    it 'raises NoMethodError for audit_message' do
      expect { abstract_service.send(:audit_message) }.to raise_error(NoMethodError)
    end

    it 'raises NoMethodError for audit_author' do
      expect { abstract_service.send(:audit_author) }.to raise_error(NoMethodError)
    end
  end
end
