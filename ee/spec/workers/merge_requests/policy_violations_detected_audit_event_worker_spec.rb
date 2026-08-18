# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::PolicyViolationsDetectedAuditEventWorker, feature_category: :security_policy_management do
  describe '#perform' do
    let(:worker) { described_class.new }

    include_examples 'an idempotent worker' do
      let_it_be(:merge_request) { create(:merge_request) }

      let(:job_args) { merge_request.id }
    end

    context 'when a merge request is not found' do
      it 'logs and does not call PolicyViolationsDetectedAuditEventService' do
        expect(Sidekiq.logger).to receive(:info).with(
          hash_including('message' => 'Merge request not found.', 'merge_request_id' => non_existing_record_id)
        )
        expect(MergeRequests::PolicyViolationsDetectedAuditEventService).not_to receive(:new).with(anything)

        worker.perform(non_existing_record_id)
      end
    end

    context 'when a merge request is found' do
      let_it_be(:merge_request) { create(:merge_request) }

      it 'calls PolicyViolationsDetectedAuditEventService' do
        expect_next_instance_of(MergeRequests::PolicyViolationsDetectedAuditEventService, merge_request) do |service|
          expect(service).to receive(:execute)
        end

        worker.perform(merge_request.id)
      end
    end
  end
end
