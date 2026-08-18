# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Approvals::ScanFindingWrappedRuleSet, feature_category: :security_policy_management do
  let(:report_type) { Security::ScanResultPolicy::SCAN_FINDING }
  let_it_be_with_reload(:merge_request) { create(:merge_request) }
  let_it_be_with_reload(:approver) { create(:user) }
  let_it_be(:approval_rules) { create_list(:approval_merge_request_rule, 2, :scan_finding, merge_request: merge_request, users: [approver]) }

  let(:approval_rules_list) { approval_rules }

  subject(:wrapped_rules) { described_class.wrap(merge_request, approval_rules_list, report_type).wrapped_rules }

  describe '#wrapped_rules' do
    it 'returns only one rule' do
      expect(wrapped_rules.count).to be 1
    end

    context 'with multiple approval_policy_action_idx' do
      let_it_be(:approval_rule_with_action_idx_0) do
        create(:approval_merge_request_rule, :scan_finding,
          merge_request: merge_request,
          orchestration_policy_idx: 0,
          approval_policy_action_idx: 0,
          users: [approver]
        )
      end

      let_it_be(:approval_rule_with_action_idx_1) do
        create(:approval_merge_request_rule, :scan_finding,
          merge_request: merge_request,
          orchestration_policy_idx: 0,
          approval_policy_action_idx: 1,
          users: [approver]
        )
      end

      let_it_be(:approval_rule_with_different_policy_idx) do
        create(:approval_merge_request_rule, :scan_finding,
          merge_request: merge_request,
          orchestration_policy_idx: 1,
          users: [approver]
        )
      end

      let(:approval_rules_list) do
        [approval_rule_with_action_idx_0, approval_rule_with_action_idx_1, approval_rule_with_different_policy_idx]
      end

      it 'returns one rule for each orchestration_policy_idx and approval_policy_action_idx' do
        expect(wrapped_rules.count).to be 3

        action_indices = wrapped_rules.map { |wrapped_rule| wrapped_rule.approval_rule.approval_policy_action_idx }.uniq

        expect(action_indices).to contain_exactly(0, 1)
      end
    end

    context 'with various orchestration_policy_idx' do
      let(:orchestration_policy_idx) { 0 }
      let(:approval_rules_w_policy_idx) { create_list(:approval_merge_request_rule, 2, :scan_finding, merge_request: merge_request, orchestration_policy_idx: orchestration_policy_idx, users: [approver]) }
      let(:approval_rules_list) { approval_rules + approval_rules_w_policy_idx }

      it 'returns one rule for each orchestration_policy_idx' do
        expect(wrapped_rules.count).to be 2

        orchestration_policy_indices = wrapped_rules.map { |wrapped_rule| wrapped_rule.approval_rule.orchestration_policy_idx }

        expect(orchestration_policy_indices).to contain_exactly(nil, orchestration_policy_idx)
      end

      context 'when all rules are approved' do
        let(:approval_rules_list) { approval_rules_w_policy_idx }

        it 'returns the first rule from the group' do
          selected_rules = wrapped_rules.select do |wrapped_rule|
            wrapped_rule.approval_rule.orchestration_policy_idx == orchestration_policy_idx
          end

          expect(selected_rules.count).to be 1
          expect(selected_rules.first.id).to be approval_rules_w_policy_idx.first.id
        end
      end

      context 'with unapproved rules' do
        let(:unapproved_rule) { create(:approval_merge_request_rule, :scan_finding, merge_request: merge_request, orchestration_policy_idx: orchestration_policy_idx, users: [approver], approvals_required: 5) }
        let(:approval_rules_list) { approval_rules + approval_rules_w_policy_idx + [unapproved_rule] }

        it 'selects the unapproved rule' do
          selected_rules = wrapped_rules.select { |wrapped_rule| wrapped_rule.approval_rule.orchestration_policy_idx == orchestration_policy_idx }

          expect(selected_rules.count).to be 1
          expect(selected_rules.first.id).to be unapproved_rule.id
        end

        it 'selects the unapproved rule even when it appears first' do
          rules_with_unapproved_first = [unapproved_rule] + approval_rules_w_policy_idx
          rule_set = described_class.new(merge_request, rules_with_unapproved_first)

          selected = rule_set.wrapped_rules.select do |wrapped_rule|
            wrapped_rule.approval_rule.orchestration_policy_idx == orchestration_policy_idx
          end

          expect(selected.count).to be 1
          expect(selected.first.id).to be unapproved_rule.id
        end
      end
    end

    context 'with various security_orchestration_policy_configuration_id' do
      let(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration) }
      let(:security_orchestration_policy_configuration_2) { create(:security_orchestration_policy_configuration) }
      let(:approval_rules_w_sec_orch_config) { create_list(:approval_merge_request_rule, 2, :scan_finding, merge_request: merge_request, users: [approver], security_orchestration_policy_configuration: security_orchestration_policy_configuration) }
      let(:approval_rules_w_sec_orch_config_2) { create_list(:approval_merge_request_rule, 2, :scan_finding, merge_request: merge_request, users: [approver], security_orchestration_policy_configuration: security_orchestration_policy_configuration_2) }
      let(:approval_rules_list) { approval_rules + approval_rules_w_sec_orch_config + approval_rules_w_sec_orch_config_2 }

      it 'returns one rule for each security_orchestration_policy_configuration_id' do
        expect(wrapped_rules.count).to be 3

        security_orchestration_policy_configuration_ids = wrapped_rules.map { |wrapped_rule| wrapped_rule.approval_rule.security_orchestration_policy_configuration_id }

        expect(security_orchestration_policy_configuration_ids).to contain_exactly(nil, security_orchestration_policy_configuration.id, security_orchestration_policy_configuration_2.id)
      end
    end
  end
end
