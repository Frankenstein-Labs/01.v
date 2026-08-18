# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::MergeRequests::ProcessMergeAuditEventWorker, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, :with_productivity_metrics, :merged, source_project: project) }

  let(:data) { { merge_request_id: merge_request.id } }
  let(:merged_event) { MergeRequests::MergedEvent.new(data: data) }

  before do
    merge_request.metrics.update_columns merged_by_id: user.id
  end

  it_behaves_like 'subscribes to event' do
    let(:event) { merged_event }
  end

  it 'calls MergeRequests::MergeAuditEventSerivce' do
    expect_next_instance_of(
      MergeRequests::MergeAuditEventService,
      merge_request: merge_request
    ) do |service|
      expect(service).to receive(:execute)
    end

    described_class.new.perform(merged_event.class.name, merged_event.data)
  end

  context 'when the merge request does not exist' do
    it 'logs and does not call MergeRequests::MergeAuditEventService' do
      merge_request.destroy!

      expect(Sidekiq.logger).to receive(:info)
      expect(MergeRequests::MergeAuditEventService).not_to receive(:new)

      expect { described_class.new.perform(merged_event.class.name, merged_event.data) }.not_to raise_exception
    end
  end
end
