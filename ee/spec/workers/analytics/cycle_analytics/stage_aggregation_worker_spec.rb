# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::StageAggregationWorker, feature_category: :value_stream_management do
  subject(:worker) { described_class.new }

  it_behaves_like 'an idempotent worker'

  context 'when the loaded batch is empty' do
    it 'does nothing' do
      expect(Analytics::CycleAnalytics::StageAggregatorService).not_to receive(:new)

      worker.perform
    end
  end

  it 'invokes the StageAggregatorService' do
    aggregation = create(:cycle_analytics_stage_aggregation)

    expect(Analytics::CycleAnalytics::StageAggregatorService).to receive(:new)
      .with(
        aggregation: aggregation,
        runtime_limiter: instance_of(Gitlab::Metrics::RuntimeLimiter)
      )
      .and_call_original

    worker.perform
  end

  it 'breaks at the second iteration due to overtime' do
    create_list(:cycle_analytics_stage_aggregation, 2)

    first_monotonic_time = 100
    second_monotonic_time = first_monotonic_time + described_class.const_get(:MAX_RUNTIME, false).to_i + 10

    expect(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(first_monotonic_time, second_monotonic_time)
    expect(Analytics::CycleAnalytics::StageAggregatorService).to receive(:new).and_call_original.exactly(:once)

    worker.perform
  end
end
