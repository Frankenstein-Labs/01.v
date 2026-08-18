# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::ApprovalRules::DeleteService, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let_it_be(:security_policy) do
    create(:security_policy, security_orchestration_policy_configuration: security_orchestration_policy_configuration)
  end

  let_it_be(:approval_policy_rules) { create_list(:approval_policy_rule, 2, security_policy: security_policy) }

  let_it_be(:rules) { security_policy.approval_policy_rules }

  let(:service) do
    described_class.new(
      project: project,
      security_policy: security_policy,
      approval_policy_rules: rules
    )
  end

  describe '#execute' do
    subject(:execute_service) { service.execute }

    it 'deletes approval policy rules for project' do
      expect(security_policy).to receive(:delete_approval_policy_rules_for_project)
                                   .with(project, approval_policy_rules)

      execute_service
    end

    context 'when approval policy rules is empty' do
      let_it_be(:rules) { Security::ApprovalPolicyRule.none }

      it 'does not delete approval policy rules for project' do
        expect(security_policy).not_to receive(:delete_approval_policy_rules_for_project)

        execute_service
      end
    end
  end
end
