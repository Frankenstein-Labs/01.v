# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ApprovalRules::UpdateService, feature_category: :security_policy_management do
  let_it_be(:author) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be_with_reload(:security_policy) do
    create(:security_policy,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration,
      content: {
        actions: [
          {
            type: 'require_approval',
            approvals_required: 1,
            user_approvers: ['admin']
          }
        ]
      }
    )
  end

  let_it_be_with_reload(:approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }

  let_it_be_with_reload(:scan_result_policy_read) do
    create(:scan_result_policy_read,
      project: project,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration,
      approval_policy_rule_id: approval_policy_rule.id,
      action_idx: 0)
  end

  let_it_be_with_reload(:project_approval_rule) do
    create(:approval_project_rule, :scan_finding,
      project: project,
      approvals_required: 1,
      approval_policy_rule: approval_policy_rule,
      scan_result_policy_read: scan_result_policy_read,
      security_orchestration_policy_configuration: security_orchestration_policy_configuration,
      approval_policy_action_idx: 0)
  end

  let_it_be_with_reload(:approval_policy_rules) { [approval_policy_rule] }

  subject(:execute_service) do
    described_class.new(
      project: project,
      security_policy: security_policy,
      approval_policy_rules: approval_policy_rules,
      author: author
    ).execute
  end

  before do
    security_policy.clear_memoization(:policy_content)
    approval_policy_rule.clear_memoization(:rule)
  end

  describe '#execute' do
    context 'when there are no approval actions' do
      before do
        security_policy.update!(content: { actions: [] })
      end

      it 'updates both scan result policy read and approval_rule' do
        expect { execute_service }.to change { scan_result_policy_read.reload.updated_at }
          .and change { project_approval_rule.reload.updated_at }
      end
    end

    context 'when there are approval actions' do
      before do
        security_policy.update!(content: {
          actions: [
            {
              type: 'require_approval',
              approvals_required: 2,
              user_approvers: ['admin']
            }
          ]
        })
      end

      it 'updates both scan result policy read and approvals required' do
        expect { execute_service }.to change { scan_result_policy_read.reload.updated_at }
          .and change { project_approval_rule.reload.approvals_required }.from(1).to(2)
      end
    end

    context 'when there are multiple approval actions' do
      let_it_be(:second_scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          approval_policy_rule_id: approval_policy_rule.id,
          action_idx: 1)
      end

      let_it_be(:second_project_approval_rule) do
        create(:approval_project_rule, :scan_finding,
          project: project,
          approvals_required: 1,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: second_scan_result_policy_read,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          approval_policy_action_idx: 1)
      end

      before do
        security_policy.update!(content: {
          actions: [
            {
              type: 'require_approval',
              approvals_required: 2,
              user_approvers: ['admin']
            },
            {
              type: 'require_approval',
              approvals_required: 3,
              user_approvers: ['maintainer']
            }
          ]
        })
      end

      it 'updates all scan result policy reads and approvals required for each action' do
        expect { execute_service }
          .to change { scan_result_policy_read.reload.updated_at }
          .and change { second_scan_result_policy_read.reload.updated_at }
          .and change { project_approval_rule.reload.approvals_required }.from(1).to(2)
          .and change { second_project_approval_rule.reload.approvals_required }.from(1).to(3)
      end
    end

    context 'when rule is license finding type' do
      before do
        create(:software_license_policy,
          project: project,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: scan_result_policy_read
        )

        approval_policy_rule.update!(type: Security::ApprovalPolicyRule.types[:license_finding], content: content)
      end

      shared_examples_for 'updates scan result policy read, project approval rule and software license policy' do
        it 'updates scan result policy read, project approval rule and software license policy' do
          expect { execute_service }
            .to change { scan_result_policy_read.reload.updated_at }
            .and change { project_approval_rule.reload.updated_at }

          expect(SoftwareLicensePolicy.last.approval_policy_rule).to eq(approval_policy_rule)
        end
      end

      context 'when using the license_types property' do
        let(:content) do
          {
            type: 'license_finding',
            match_on_inclusion_license: true,
            branches: [],
            license_states: ['newly_detected'],
            license_types: ['MIT']
          }
        end

        it_behaves_like 'updates scan result policy read, project approval rule and software license policy'
      end

      context 'when using the licenses property' do
        let(:content) do
          {
            type: 'license_finding',
            match_on_inclusion_license: true,
            branches: [],
            license_states: ['newly_detected'],
            licenses: licenses
          }
        end

        context 'when using the denied property' do
          let(:licenses) { { denied: [{ name: 'MIT' }] } }

          it_behaves_like 'updates scan result policy read, project approval rule and software license policy'
        end

        context 'when using the allowed property' do
          let(:licenses) { { allowed: [{ name: 'MIT' }] } }

          it_behaves_like 'updates scan result policy read, project approval rule and software license policy'
        end
      end
    end

    context 'when multiple approval policy rules exist' do
      let_it_be(:another_approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }
      let_it_be(:another_scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          orchestration_policy_idx: 1,
          approval_policy_rule_id: another_approval_policy_rule.id,
          action_idx: 0)
      end

      let_it_be(:another_project_approval_rule) do
        create(:approval_project_rule, :scan_finding,
          project: project,
          approval_policy_rule: another_approval_policy_rule,
          scan_result_policy_read: another_scan_result_policy_read,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          approval_policy_action_idx: 0)
      end

      let_it_be(:approval_policy_rules) { [approval_policy_rule, another_approval_policy_rule] }

      before do
        security_policy.update!(content: {
          actions: [
            {
              type: 'require_approval',
              approvals_required: 2,
              user_approvers: ['admin']
            }
          ]
        })
      end

      it 'updates scan result policy reads and project approval rules' do
        expect { execute_service }
          .to change { another_scan_result_policy_read.reload.updated_at }
          .and change { another_project_approval_rule.reload.updated_at }
      end
    end

    context 'when project_approval_rules_map does not contain the rule' do
      let_it_be(:new_approval_policy_rule) { create(:approval_policy_rule, security_policy: security_policy) }
      let_it_be(:new_scan_result_policy_read) do
        create(:scan_result_policy_read,
          project: project,
          security_orchestration_policy_configuration: security_orchestration_policy_configuration,
          approval_policy_rule_id: new_approval_policy_rule.id,
          action_idx: 0)
      end

      let_it_be(:approval_policy_rules) { [new_approval_policy_rule] }

      before do
        security_policy.update!(content: {
          actions: [
            {
              type: 'require_approval',
              approvals_required: 2,
              user_approvers: ['admin']
            }
          ]
        })
      end

      it 'updates scan_result_policy_read but does not update approval rule' do
        expect { execute_service }
          .to change { new_scan_result_policy_read.reload.updated_at }
          .and not_change { ApprovalProjectRule.count }
      end
    end

    context 'when approval rule update fails' do
      before do
        allow_next_instance_of(::ApprovalRules::UpdateService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'failed'))
        end
      end

      it 'logs the error with Gitlab::AppJsonLogger.debug' do
        expect(Gitlab::AppJsonLogger).to receive(:debug).with(hash_including(
          "event" => "approval_rule_updation_failed",
          "project_id" => project.id,
          "project_path" => project.full_path,
          "scan_result_policy_read_id" => scan_result_policy_read.id,
          "approval_policy_rule_id" => approval_policy_rule.id,
          "action_index" => 0,
          "errors" => ['failed']
        ))

        execute_service
      end
    end
  end
end
