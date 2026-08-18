# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::MergeRequests::Mergeability::DetailedMergeStatusService, feature_category: :code_review_workflow do
  subject(:detailed_merge_status) { described_class.new(merge_request: merge_request).execute }

  let(:merge_request) { create(:merge_request) }

  context 'when the MR is not approved' do
    before do
      create(:any_approver_rule, merge_request: merge_request, approvals_required: 2)
    end

    context 'when the MR is not temporarily unapproved' do
      it 'returns not_approved status' do
        expect(detailed_merge_status).to eq(:not_approved)
      end
    end

    context 'when the MR is temporarily unapproved' do
      before do
        merge_request.approval_state.temporarily_unapprove!
      end

      it 'returns approvals_syncing status' do
        expect(detailed_merge_status).to eq(:approvals_syncing)
      end
    end
  end

  describe 'skip_rebase_check with merge trains' do
    let(:project) { merge_request.project }

    before do
      allow(merge_request).to receive(:should_be_rebased?).and_return(true)
      allow(project).to receive(:ff_merge_must_be_possible?).and_return(true)
    end

    context 'when merge trains are not using fast-forward' do
      before do
        allow(MergeTrains::Train).to receive(:project_using_ff?).with(project).and_return(false)
      end

      it 'returns need_rebase status' do
        expect(detailed_merge_status).to eq(:need_rebase)
      end
    end

    context 'when merge trains are using fast-forward' do
      before do
        allow(MergeTrains::Train).to receive(:project_using_ff?).with(project).and_return(true)
      end

      it 'returns mergeable status' do
        expect(detailed_merge_status).to eq(:mergeable)
      end
    end
  end
end
