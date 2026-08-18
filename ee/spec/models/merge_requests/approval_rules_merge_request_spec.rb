# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRulesMergeRequest, type: :model, feature_category: :code_review_workflow do
  let(:merge_request) { create(:merge_request) }

  describe 'associations' do
    it { is_expected.to belong_to(:approval_rule) }
    it { is_expected.to belong_to(:merge_request) }
  end

  describe 'validations' do
    context 'when adding the same merge request to an approval rule' do
      let(:group) { create(:group) }
      let(:approval_rule) { create(:merge_requests_approval_rule, group_id: group.id) }

      before do
        create(:merge_requests_approval_rules_merge_request, approval_rule: approval_rule,
          merge_request: merge_request, project_id: merge_request.project_id)
      end

      it 'is not valid' do
        duplicate_approval_rules_merge_request = build(:merge_requests_approval_rules_merge_request,
          approval_rule: approval_rule, merge_request_id: merge_request.id, project_id: merge_request.project_id)
        expect(duplicate_approval_rules_merge_request).not_to be_valid
        expect(duplicate_approval_rules_merge_request.errors[:merge_request_id]).to include('has already been taken')
      end
    end
  end

  describe 'callbacks' do
    describe 'after_destroy' do
      let(:project) { merge_request.project }
      let(:approval_rule) do
        create(:merge_requests_approval_rule, merge_request: merge_request, origin: :merge_request,
          project_id: project.id)
      end

      let(:approval_rule_mr_join) { approval_rule.approval_rules_merge_request }

      context 'when approval rule originates from merge request' do
        context 'when approval rule is only associated with this merge request' do
          it 'destroys the approval rule' do
            approval_rule

            expect(described_class.count).to eq(1)
            expect(MergeRequests::ApprovalRule.count).to eq(1)
            expect { approval_rule_mr_join.destroy! }.to change { MergeRequests::ApprovalRule.count }.from(1).to(0)
          end
        end

        context 'when approval rule is associated with multiple merge requests' do
          let(:merge_request_2) { create(:merge_request) }
          let!(:approval_rule_mr_join_2) do
            create(:merge_requests_approval_rules_merge_request, approval_rule: approval_rule,
              merge_request: merge_request_2, project_id: merge_request_2.project_id)
          end

          it 'does not destroy the approval rule' do
            expect { approval_rule_mr_join.destroy! }.not_to change { MergeRequests::ApprovalRule.count }
            expect { approval_rule.reload }.not_to raise_error
          end
        end
      end

      context 'when approval rule originates from project' do
        let(:approval_rule) do
          create(:merge_requests_approval_rule, merge_request: merge_request, origin: :project, project_id: project.id)
        end

        it 'does not destroy the approval rule' do
          approval_rule

          expect { approval_rule_mr_join.destroy! }.not_to change { MergeRequests::ApprovalRule.count }
          expect { approval_rule.reload }.not_to raise_error
        end
      end

      context 'when approval rule originates from group' do
        let(:group) { create(:group) }
        let(:approval_rule) do
          create(:merge_requests_approval_rule, merge_request: merge_request, origin: :group, group_id: group.id)
        end

        it 'does not destroy the approval rule' do
          approval_rule

          expect { approval_rule_mr_join.destroy! }.not_to change { MergeRequests::ApprovalRule.count }
          expect { approval_rule.reload }.not_to raise_error
        end
      end
    end
  end
end
