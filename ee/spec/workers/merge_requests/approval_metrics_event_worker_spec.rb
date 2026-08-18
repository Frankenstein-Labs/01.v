# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::ApprovalMetricsEventWorker, feature_category: :code_review_workflow do
  let(:merge_request) { create(:merge_request) }
  let(:approved_at) { Time.current }
  let(:event_data) { { merge_request_id: merge_request.id, approved_at: approved_at } }
  let(:event) { instance_double(Gitlab::EventStore::Event, data: event_data) }

  describe '#handle_event' do
    subject(:worker) { described_class.new }

    context 'when merge request exists' do
      it 'calls ApprovalMetrics.refresh_last_approved_at' do
        expect(MergeRequest::ApprovalMetrics).to receive(:refresh_last_approved_at)
          .with(
            merge_request: merge_request,
            last_approved_at: approved_at
          )

        worker.handle_event(event)
      end
    end

    context 'when merge request does not exist' do
      let(:event_data) { super().merge(merge_request_id: non_existing_record_id) }

      it 'does not call ApprovalMetrics.refresh_last_approved_at' do
        expect(MergeRequest::ApprovalMetrics).not_to receive(:refresh_last_approved_at)

        worker.handle_event(event)
      end
    end
  end
end
