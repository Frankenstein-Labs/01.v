# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics::KnowledgeGraph::Request, feature_category: :knowledge_graph do
  let(:histogram) { instance_double(Prometheus::Client::Histogram) }
  let(:counter) { instance_double(Prometheus::Client::Counter) }

  before do
    described_class.instance_variable_set(:@histograms, nil)
    described_class.instance_variable_set(:@counters, nil)
    allow(Gitlab::Metrics).to receive_messages(histogram: histogram, counter: counter)
  end

  describe '.measure' do
    it 'yields the block and returns its result' do
      allow(histogram).to receive(:observe)

      result = described_class.measure(:gitlab_knowledge_graph_grpc_duration_seconds) { 'value' }

      expect(result).to eq('value')
    end

    it 'observes duration on the named histogram' do
      allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(100.0, 100.05)

      expect(histogram).to receive(:observe).with({}, a_value_within(0.001).of(0.05))

      described_class.measure(:gitlab_knowledge_graph_grpc_duration_seconds) { nil }
    end

    it 'passes labels to the histogram' do
      allow(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(0.0, 0.1)

      expect(histogram).to receive(:observe).with({ method: 'test' }, 0.1)

      described_class.measure(:gitlab_knowledge_graph_grpc_duration_seconds, { method: 'test' }) { nil }
    end
  end

  describe '.observe_grpc_duration' do
    it 'observes duration with method and status labels' do
      expect(histogram).to receive(:observe).with({ method: 'list_tools', status: 'ok' }, 0.05)

      described_class.observe_grpc_duration('list_tools', 'ok', 0.05)
    end
  end

  describe '.observe_redaction_duration' do
    it 'observes the redaction service duration' do
      expect(histogram).to receive(:observe).with({}, 0.1)

      described_class.observe_redaction_duration(0.1)
    end
  end

  describe '.observe_redaction_batch_size' do
    it 'observes the batch size' do
      expect(histogram).to receive(:observe).with({}, 25)

      described_class.observe_redaction_batch_size(25)
    end
  end

  describe '.observe_redaction_filtered' do
    it 'observes the filtered count' do
      expect(histogram).to receive(:observe).with({}, 3)

      described_class.observe_redaction_filtered(3)
    end
  end

  describe '.observe_jwt_duration' do
    it 'observes the JWT build duration' do
      expect(histogram).to receive(:observe).with({}, 0.004)

      described_class.observe_jwt_duration(0.004)
    end
  end

  describe '.observe_auth_context_duration' do
    it 'observes the auth context duration' do
      expect(histogram).to receive(:observe).with({}, 0.02)

      described_class.observe_auth_context_duration(0.02)
    end
  end

  describe '.increment_grpc_error' do
    it 'increments the error counter with method and code labels' do
      expect(counter).to receive(:increment).with({ method: 'execute_query', code: '14' })

      described_class.increment_grpc_error('execute_query', '14')
    end
  end
end
