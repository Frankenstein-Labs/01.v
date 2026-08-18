# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ApprovalRules::V2::DataMapper, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be_with_reload(:user1) { create(:user) }
  let_it_be_with_reload(:user2) { create(:user) }
  let_it_be_with_reload(:v1_rule) do
    create(
      :approval_merge_request_rule,
      merge_request: merge_request,
      name: 'Test Rule',
      approvals_required: 2,
      rule_type: :regular,
      users: [user1, user2]
    )
  end

  describe '#migrate' do
    context 'when v2_approval_rules is not enabled' do
      subject(:mapper) { described_class.new(v1_rule) }

      before do
        stub_feature_flags(v2_approval_rules: false)
      end

      it 'does not create a new approval rule records' do
        expect { mapper.migrate }.not_to change {
          ::MergeRequests::ApprovalRule.count
        }

        expect { mapper.migrate }.not_to change {
          ::MergeRequests::ApprovalRulesMergeRequest.count
        }
      end
    end

    context 'when v2_approval_rules is enabled' do
      before do
        stub_feature_flags(v2_approval_rules: true)
      end

      context 'when v1_rule is not present' do
        subject(:mapper) { described_class.new(nil) }

        it 'does not create a new approval rule records' do
          expect { mapper.migrate }.not_to change {
            ::MergeRequests::ApprovalRule.count
          }

          expect { mapper.migrate }.not_to change {
            ::MergeRequests::ApprovalRulesMergeRequest.count
          }
        end
      end

      context 'when v1 rule is a merge request level rule' do
        subject(:mapper) { described_class.new(v1_rule) }

        it 'creates a v2 approval rule with correct attributes' do
          v2_rule = mapper.migrate

          expect(v2_rule).to be_a(::MergeRequests::ApprovalRule)
          expect(v2_rule.name).to eq('Test Rule')
          expect(v2_rule.approvals_required).to eq(2)
          expect(v2_rule.rule_type).to eq('regular')
          expect(v2_rule.origin).to eq('merge_request')
          expect(v2_rule.project_id).to eq(project.id)
        end

        it 'creates merge request association' do
          v2_rule = mapper.migrate

          expect(v2_rule.merge_request).to eq(merge_request)
          expect(::MergeRequests::ApprovalRulesMergeRequest.where(
            approval_rule: v2_rule,
            merge_request: merge_request
          )).to exist
        end

        it 'migrates user associations' do
          v2_rule = mapper.migrate

          expect(v2_rule.approver_users).to match_array([user1, user2])
          expect(::MergeRequests::ApprovalRulesApproverUser.where(approval_rule: v2_rule).count).to eq(2)
        end

        context 'with different rule types' do
          it 'maps regular rule type correctly' do
            v1_rule.update!(rule_type: :regular)
            v2_rule = mapper.migrate
            expect(v2_rule.rule_type).to eq('regular')
          end

          it 'maps code_owner rule type correctly' do
            v1_rule.update!(rule_type: :code_owner)
            v2_rule = mapper.migrate
            expect(v2_rule.rule_type).to eq('code_owner')
          end

          it 'maps report_approver rule type correctly' do
            v1_rule.update!(rule_type: :report_approver, report_type: :license_scanning)
            v2_rule = mapper.migrate
            expect(v2_rule.rule_type).to eq('report_approver')
          end

          it 'maps any_approver rule type correctly' do
            v1_rule.update!(rule_type: :any_approver)
            v2_rule = mapper.migrate
            expect(v2_rule.rule_type).to eq('any_approver')
          end
        end

        it 'handles rules without users' do
          v1_rule_without_associations = create(:approval_merge_request_rule,
            merge_request: merge_request,
            name: 'Empty Rule',
            users: []
          )
          mapper = described_class.new(v1_rule_without_associations)

          v2_rule = mapper.migrate

          expect(v2_rule.approver_users).to be_empty
        end

        it 'performs migration in a transaction' do
          allow(::MergeRequests::ApprovalRule).to receive(:create!).and_raise(StandardError, 'Test error')

          expect { mapper.migrate }.to raise_error(StandardError, 'Test error')
          expect(::MergeRequests::ApprovalRule.count).to eq(0)
          expect(::MergeRequests::ApprovalRulesMergeRequest.count).to eq(0)
        end
      end

      context 'when v1 rule is not a merge request level rule' do
        let(:v1_rule) do
          build(:approval_project_rule)
        end

        subject(:mapper) { described_class.new(v1_rule) }

        it 'returns nil and does not create v2 rule' do
          result = mapper.migrate

          expect(result).to be_nil
          expect(::MergeRequests::ApprovalRule.count).to eq(0)
        end
      end
    end
  end
end
