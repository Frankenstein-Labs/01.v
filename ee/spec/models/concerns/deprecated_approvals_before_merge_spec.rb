# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DeprecatedApprovalsBeforeMerge, feature_category: :source_code_management do
  shared_examples 'with approvals before merge deprecated' do
    context 'when updating approvals_before_merge' do
      it 'creates any_approver rule' do
        subject.update!(approvals_before_merge: 3)

        expect_approvals_before_merge_to_be_updated(3)

        subject.update!(approvals_before_merge: 5)

        expect_approvals_before_merge_to_be_updated(5)
      end
    end
  end

  context 'for unmerged merge request' do
    subject { create(:merge_request, approvals_before_merge: 2) }

    it_behaves_like 'with approvals before merge deprecated'
  end

  context 'for merged MR' do
    subject(:merge_request) { create(:merge_request, :merged, approvals_before_merge: 2) }

    it 'does not change approval rules' do
      expect(merge_request).not_to receive(:update_any_approver_rule)

      merge_request.update!(approvals_before_merge: 3)
    end
  end

  context 'for project' do
    subject { create(:project, approvals_before_merge: 2) }

    it_behaves_like 'with approvals before merge deprecated'
  end

  def expect_approvals_before_merge_to_be_updated(value)
    expect(subject.approval_rules.any_approver.size).to eq(1)

    rule = subject.approval_rules.any_approver.first
    expect(rule.approvals_required).to eq(value)
  end
end
