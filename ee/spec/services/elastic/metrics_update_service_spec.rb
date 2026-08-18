# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::MetricsUpdateService, :prometheus, feature_category: :global_search do
  subject { described_class.new }

  describe '#execute' do
    it 'sets gauges' do
      expect(Elastic::ProcessBookkeepingService).to receive(:queue_size).and_return(4).once
      expect(Elastic::ProcessInitialBookkeepingService).to receive(:queue_size).and_return(6).once
      expect(Search::Elastic::DeadQueue).to receive(:queue_size).and_return(2).once

      incremental_gauge_double = instance_double(Prometheus::Client::Gauge)
      expect(Gitlab::Metrics).to receive(:gauge)
        .with(:search_advanced_bulk_cron_queue_size, anything, {}, :max)
        .and_return(incremental_gauge_double)

      initial_gauge_double = instance_double(Prometheus::Client::Gauge)
      expect(Gitlab::Metrics).to receive(:gauge)
        .with(:search_advanced_bulk_cron_initial_queue_size, anything, {}, :max)
        .and_return(initial_gauge_double)

      dead_gauge_double = instance_double(Prometheus::Client::Gauge)
      expect(Gitlab::Metrics).to receive(:gauge)
        .with(:search_advanced_bulk_cron_dead_queue_size, anything, {}, :max)
        .and_return(dead_gauge_double)

      expect(incremental_gauge_double).to receive(:set).with({}, 4)
      expect(initial_gauge_double).to receive(:set).with({}, 6)
      expect(dead_gauge_double).to receive(:set).with({}, 2)

      subject.execute
    end
  end
end
