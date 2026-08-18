# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::CreateApprovalsResetNoteWorker, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:approver) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let(:data) do
    {
      current_user_id: user.id,
      merge_request_id: merge_request.id,
      cause: 'new_push',
      approver_ids: [approver.id]
    }
  end

  let(:approvals_reset_event) { MergeRequests::ApprovalsResetEvent.new(data: data) }

  it_behaves_like 'subscribes to event' do
    let(:event) { approvals_reset_event }
  end

  it 'calls SystemNoteService.approvals_reset' do
    expect(SystemNoteService).to receive(:approvals_reset).with(merge_request, user, :new_push, [approver])

    consume_event(subscriber: described_class, event: approvals_reset_event)
  end

  shared_examples 'when object does not exist' do
    it 'logs and does not call SystemNoteService.approvals_reset' do
      expect(Sidekiq.logger).to receive(:info).with(hash_including(log_payload))
      expect(SystemNoteService).not_to receive(:approvals_reset)

      expect { consume_event(subscriber: described_class, event: approvals_reset_event) }
        .not_to raise_exception
    end
  end

  context 'when the user does not exist' do
    before do
      user.destroy!
    end

    it_behaves_like 'when object does not exist' do
      let(:log_payload) { { 'message' => 'Current user not found.', 'current_user_id' => user.id } }
    end
  end

  context 'when the merge request does not exist' do
    before do
      merge_request.destroy!
    end

    it_behaves_like 'when object does not exist' do
      let(:log_payload) { { 'message' => 'Merge request not found.', 'merge_request_id' => merge_request.id } }
    end
  end
end
