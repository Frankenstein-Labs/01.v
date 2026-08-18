# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalRulesGroup, type: :model, feature_category: :code_review_workflow do
  describe 'associations' do
    it { is_expected.to belong_to(:approval_rule) }
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    context 'when adding the same group to an approval rule' do
      let(:group) { create(:group) }
      let(:approval_rule) { create(:merge_requests_approval_rule, group_id: group.id) }

      before do
        create(:merge_requests_approval_rules_group, approval_rule: approval_rule, group: group)
      end

      it 'is not valid' do
        duplicate_approval_rules_group = build(:merge_requests_approval_rules_group, approval_rule: approval_rule,
          group_id: group.id)
        expect(duplicate_approval_rules_group).not_to be_valid
        expect(duplicate_approval_rules_group.errors[:group_id]).to include('has already been taken')
      end
    end
  end
end
