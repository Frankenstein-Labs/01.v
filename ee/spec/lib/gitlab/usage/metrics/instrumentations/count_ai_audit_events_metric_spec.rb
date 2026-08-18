# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountAiAuditEventsMetric,
  feature_category: :duo_agent_platform do
  context 'with time_frame all' do
    before do
      create_list(:audit_events_ai_audit_event, 3)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'all', data_source: 'database' } do
      let(:expected_value) { 3 }
    end
  end

  context 'with time_frame 28d' do
    # The 28d frame uses the Service Ping monthly window (30.days.ago..2.days.ago),
    # so events older than 30 days AND newer than 2 days ago are both excluded.
    before do
      create_list(:audit_events_ai_audit_event, 2, created_at: 5.days.ago)
      create(:audit_events_ai_audit_event, created_at: 40.days.ago) # too old
      create(:audit_events_ai_audit_event, created_at: 1.day.ago)   # too recent
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: '28d', data_source: 'database' } do
      let(:expected_value) { 2 }
    end
  end

  context 'when no audit events exist' do
    it_behaves_like 'a correct instrumented metric value', { time_frame: 'all', data_source: 'database' } do
      let(:expected_value) { 0 }
    end
  end

  context 'when the count raises a database error' do
    before do
      allow(Gitlab::ErrorTracking).to receive(:should_raise_for_dev?).and_return(false)
      allow(::Gitlab::Database::BatchCount).to receive(:batch_count)
        .and_raise(ActiveRecord::StatementInvalid, 'boom')
    end

    it 'returns the -1 fallback' do
      expect(described_class.new(time_frame: 'all').value).to eq(-1)
    end
  end
end
