# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::NotifyApproversWorker, feature_category: :code_review_workflow do
  describe '#perform' do
    let(:worker) { described_class.new }

    context 'when a merge request is not found' do
      it 'logs merge request not found' do
        expect(Sidekiq.logger).to receive(:info).with(
          hash_including('message' => 'Merge request not found.', 'merge_request_id' => non_existing_record_id)
        )

        worker.perform(non_existing_record_id)
      end
    end

    context 'when a merge request is found' do
      let_it_be(:merge_request) { create(:merge_request) }

      it 'calls notify_approvers' do
        expect_next_found_instance_of(MergeRequest) do |instance|
          expect(instance).to receive(:notify_approvers)
        end

        worker.perform(merge_request.id)
      end
    end
  end
end
