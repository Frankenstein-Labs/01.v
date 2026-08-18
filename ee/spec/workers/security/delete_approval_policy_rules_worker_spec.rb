# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DeleteApprovalPolicyRulesWorker, feature_category: :security_policy_management do
  let_it_be(:approval_policy_rule) { create(:approval_policy_rule, rule_index: -1) }
  let_it_be(:other_approval_policy_rule) { create(:approval_policy_rule, rule_index: -2) }
  let_it_be(:project) { create(:project) }

  let(:approval_policy_rule_ids) { [approval_policy_rule.id] }

  describe '#perform' do
    subject(:perform) { described_class.new.perform(approval_policy_rule_ids) }

    context 'when approval policy rules are linked to projects' do
      before do
        create(:approval_policy_rule_project_link, approval_policy_rule: approval_policy_rule, project: project)
      end

      it 'raises ProjectLinkExistsError' do
        expect { perform }.to raise_error(described_class::ProjectLinkExistsError)
      end
    end

    context 'when approval policy rules are not linked to projects' do
      it 'deletes only the specified deleted approval policy rules' do
        perform

        expect(Security::ApprovalPolicyRule.exists?(approval_policy_rule.id)).to be false
        expect(Security::ApprovalPolicyRule.exists?(other_approval_policy_rule.id)).to be true
      end
    end

    it_behaves_like 'an idempotent worker' do
      let(:job_args) { [approval_policy_rule_ids] }
    end
  end
end
