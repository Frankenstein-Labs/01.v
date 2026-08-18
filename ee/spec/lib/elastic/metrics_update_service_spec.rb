# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::MetricsUpdateService, feature_category: :global_search do
  describe '#execute' do
    it 'sets gauges with queue sizes' do
      gauge_mock = instance_double(Prometheus::Client::Gauge)
      allow(Gitlab::Metrics).to receive(:gauge).and_return(gauge_mock)

      expect(::Elastic::ProcessBookkeepingService).to receive(:queue_size).and_return(10)
      expect(::Elastic::ProcessInitialBookkeepingService).to receive(:queue_size).and_return(5)
      expect(::Search::Elastic::DeadQueue).to receive(:queue_size).and_return(42)

      expect(gauge_mock).to receive(:set).with({}, 10).ordered
      expect(gauge_mock).to receive(:set).with({}, 5).ordered
      expect(gauge_mock).to receive(:set).with({}, 42).ordered

      described_class.new.execute
    end

    it 'does not raise an error when queue size is zero' do
      allow(::Elastic::ProcessBookkeepingService).to receive(:queue_size).and_return(0)
      allow(::Elastic::ProcessInitialBookkeepingService).to receive(:queue_size).and_return(0)
      allow(::Search::Elastic::DeadQueue).to receive(:queue_size).and_return(0)

      expect { described_class.new.execute }.not_to raise_error
    end
  end
end
