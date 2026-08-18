# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountAiAuditEventsClickhouseMetric,
  feature_category: :duo_agent_platform do
  before do
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
  end

  describe '#available?' do
    it 'is available only when ClickHouse analytics is globally enabled', :aggregate_failures do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
      expect(described_class.new(time_frame: 'all').available?).to be(true)

      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
      expect(described_class.new(time_frame: 'all').available?).to be(false)
    end
  end

  context 'with time_frame all' do
    before do
      allow(ClickHouse::Client).to receive(:select)
        .with("SELECT count() AS c FROM ai_audit_events", :main)
        .and_return([{ 'c' => 42 }])
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'all', data_source: 'database' } do
      let(:expected_value) { 42 }
    end
  end

  context 'with time_frame 28d' do
    before do
      allow(ClickHouse::Client).to receive(:select)
        .with("SELECT count() AS c FROM ai_audit_events WHERE created_at >= now() - INTERVAL 28 DAY", :main)
        .and_return([{ 'c' => 7 }])
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: '28d', data_source: 'database' } do
      let(:expected_value) { 7 }
    end
  end

  context 'with an unsupported time_frame' do
    it 'raises ArgumentError' do
      expect { described_class.new(time_frame: '7d').value }
        .to raise_error(ArgumentError, /Unsupported time_frame/)
    end
  end

  context 'when ClickHouse returns no rows' do
    before do
      allow(ClickHouse::Client).to receive(:select).and_return([])
    end

    it 'returns 0 for all time_frame' do
      expect(described_class.new(time_frame: 'all').value).to eq(0)
    end

    it 'returns 0 for 28d time_frame' do
      expect(described_class.new(time_frame: '28d').value).to eq(0)
    end
  end

  context 'when ClickHouse raises an error' do
    before do
      allow(Gitlab::ErrorTracking).to receive(:should_raise_for_dev?).and_return(false)
      allow(ClickHouse::Client).to receive(:select)
        .and_raise(ClickHouse::Client::DatabaseError, 'connection refused')
    end

    it 'returns the -1 fallback' do
      expect(described_class.new(time_frame: 'all').value).to eq(-1)
    end

    it 'returns the -1 fallback for 28d' do
      expect(described_class.new(time_frame: '28d').value).to eq(-1)
    end
  end

  context 'when ClickHouse analytics is not enabled' do
    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
    end

    it 'returns the -1 fallback without querying ClickHouse' do
      expect(ClickHouse::Client).not_to receive(:select)

      expect(described_class.new(time_frame: 'all').value).to eq(-1)
    end

    it 'returns the -1 fallback for 28d without querying ClickHouse' do
      expect(ClickHouse::Client).not_to receive(:select)

      expect(described_class.new(time_frame: '28d').value).to eq(-1)
    end
  end
end
