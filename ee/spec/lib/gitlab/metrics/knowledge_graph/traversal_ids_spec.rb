# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics::KnowledgeGraph::TraversalIds, feature_category: :knowledge_graph do
  let(:histogram) { instance_double(Prometheus::Client::Histogram) }
  let(:counter) { instance_double(Prometheus::Client::Counter) }

  before do
    allow(Gitlab::Metrics).to receive_messages(histogram: histogram, counter: counter)
  end

  describe '.observe_traversal_ids_count' do
    it 'observes the traversal ID count' do
      expect(histogram).to receive(:observe).with({}, 250)

      described_class.observe_traversal_ids_count(250)
    end
  end

  describe '.observe_compaction_ratio' do
    it 'observes the compaction ratio' do
      expect(histogram).to receive(:observe).with({}, 0.5)

      described_class.observe_compaction_ratio(0.5)
    end
  end

  describe '.increment_compaction_fallback' do
    it 'increments the compaction fallback counter' do
      expect(counter).to receive(:increment).with({})

      described_class.increment_compaction_fallback
    end
  end

  describe '.increment_threshold_exceeded' do
    it 'increments the threshold exceeded counter' do
      expect(counter).to receive(:increment).with({})

      described_class.increment_threshold_exceeded
    end
  end
end
