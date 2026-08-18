# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::ActiveContext::MetricsUpdateService, :prometheus, feature_category: :global_search do
  describe '#execute' do
    let(:queue_gauge) { instance_double(Prometheus::Client::Gauge) }
    let(:dead_gauge) { instance_double(Prometheus::Client::Gauge) }

    let(:queue_counts) do
      [
        { queue_name: 'Ai::ActiveContext::Queues::Code', shard: 0, count: 4 },
        { queue_name: 'Ai::ActiveContext::Queues::Code', shard: 1, count: 0 },
        { queue_name: 'Ai::ActiveContext::Queues::Code', shard: 2, count: 2 },
        { queue_name: 'ActiveContext::RetryQueue', shard: 0, count: 7 }
      ]
    end

    before do
      allow(::ActiveContext::Queues).to receive(:queue_counts).and_return(queue_counts)
      allow(::ActiveContext::DeadQueue).to receive(:queue_size).and_return(2816889)
      allow(Gitlab::Metrics).to receive(:gauge)
        .with(:active_context_queue_size, anything, anything, :max)
        .and_return(queue_gauge)
      allow(Gitlab::Metrics).to receive(:gauge)
        .with(:active_context_dead_queue_size, anything, { queue_name: nil, shard: nil }, :max)
        .and_return(dead_gauge)
    end

    it 'sets queue size gauges per shard with :max aggregation' do
      expect(queue_gauge).to receive(:set).with({ queue_name: 'Ai::ActiveContext::Queues::Code', shard: 0 }, 4)
      expect(queue_gauge).to receive(:set).with({ queue_name: 'Ai::ActiveContext::Queues::Code', shard: 1 }, 0)
      expect(queue_gauge).to receive(:set).with({ queue_name: 'Ai::ActiveContext::Queues::Code', shard: 2 }, 2)
      expect(queue_gauge).to receive(:set).with({ queue_name: 'ActiveContext::RetryQueue', shard: 0 }, 7)
      expect(dead_gauge).to receive(:set).with({ queue_name: 'ActiveContext::DeadQueue', shard: 0 }, 2816889)

      described_class.new.execute
    end
  end
end
