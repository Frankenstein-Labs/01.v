# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoMerge::MergeWhenChecksPassService, feature_category: :code_review_workflow do
  using RSpec::Parameterized::TableSyntax

  include_context 'for auto_merge strategy context'

  let(:approval_rule) do
    create(:approval_merge_request_rule, merge_request: mr_merge_if_green_enabled,
      approvals_required: approvals_required)
  end

  describe '#available_for?' do
    subject { service.available_for?(mr_merge_if_green_enabled) }

    context 'when missing approvals' do
      let(:approval_rule) do
        create(:approval_merge_request_rule, merge_request: mr_merge_if_green_enabled,
          approvals_required: approvals_required)
      end

      let(:approvals_required) { 1 }
      let_it_be(:approver) { create(:user) }

      before do
        approval_rule.users << approver
      end

      it { is_expected.to be true }
    end

    context 'when blocked status' do
      before do
        stub_licensed_features(blocking_merge_requests: true)
        create(:merge_request_block, blocked_merge_request: mr_merge_if_green_enabled)
        allow(mr_merge_if_green_enabled).to receive(:merge_blocked_by_other_mrs?).and_return(true)
      end

      it { is_expected.to be true }
    end

    context 'when merge trains are enabled' do
      before do
        allow(mr_merge_if_green_enabled.project).to receive(:merge_trains_enabled?).and_return(true)
      end

      it { is_expected.to be false }
    end
  end
end
