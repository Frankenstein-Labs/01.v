# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Metrics::ZoektTasksSlis, feature_category: :global_search do
  describe '#initialize_slis!' do
    it 'initializes Apdex SLI for search_zoekt_tasks' do
      expect(Gitlab::Metrics::Sli::Apdex).to receive(:initialize_sli).with(:search_zoekt_tasks, [])

      described_class.initialize_slis!
    end

    it 'initializes ErrorRate SLI for search_zoekt_tasks' do
      expect(Gitlab::Metrics::Sli::ErrorRate).to receive(:initialize_sli).with(:search_zoekt_tasks, [])

      described_class.initialize_slis!
    end
  end

  describe '#increment_request_count' do
    let(:zoekt_node_id) { 1 }
    let(:task_type) { 'index' }

    it 'increments the request counter with correct labels' do
      counter = instance_double(Prometheus::Client::Counter)
      allow(described_class).to receive(:request_counter).and_return(counter)

      expect(counter).to receive(:increment).with(
        { zoekt_node: '1', task_type: 'index' },
        1
      )

      described_class.increment_request_count(zoekt_node_id: zoekt_node_id, task_type: task_type)
    end

    it 'increments by custom count when provided' do
      counter = instance_double(Prometheus::Client::Counter)
      allow(described_class).to receive(:request_counter).and_return(counter)

      expect(counter).to receive(:increment).with(
        { zoekt_node: '1', task_type: 'index' },
        5
      )

      described_class.increment_request_count(zoekt_node_id: zoekt_node_id, task_type: task_type, count: 5)
    end
  end

  describe '#increment_error_count' do
    let(:zoekt_node_id) { 2 }
    let(:task_type) { 'delete' }

    it 'increments the error rate SLI with correct labels' do
      expect(Gitlab::Metrics::Sli::ErrorRate[:search_zoekt_tasks]).to receive(:increment).with(
        labels: { zoekt_node: '2', task_type: 'delete' },
        error: true
      )

      described_class.increment_error_count(zoekt_node_id: zoekt_node_id, task_type: task_type)
    end
  end

  describe '#increment_apdex' do
    let(:zoekt_node_id) { 3 }
    let(:task_type) { 'index' }

    context 'when duration is within threshold' do
      it 'increments apdex as success' do
        duration = described_class::APDEX_THRESHOLD_S - 100

        expect(Gitlab::Metrics::Sli::Apdex[:search_zoekt_tasks]).to receive(:increment).with(
          labels: { zoekt_node: '3', task_type: 'index' },
          success: true
        )

        described_class.increment_apdex(zoekt_node_id: zoekt_node_id, task_type: task_type, duration: duration)
      end
    end

    context 'when duration exceeds threshold' do
      it 'increments apdex as failure' do
        duration = described_class::APDEX_THRESHOLD_S + 100

        expect(Gitlab::Metrics::Sli::Apdex[:search_zoekt_tasks]).to receive(:increment).with(
          labels: { zoekt_node: '3', task_type: 'index' },
          success: false
        )

        described_class.increment_apdex(zoekt_node_id: zoekt_node_id, task_type: task_type, duration: duration)
      end
    end

    context 'when duration equals threshold' do
      it 'increments apdex as success' do
        duration = described_class::APDEX_THRESHOLD_S

        expect(Gitlab::Metrics::Sli::Apdex[:search_zoekt_tasks]).to receive(:increment).with(
          labels: { zoekt_node: '3', task_type: 'index' },
          success: true
        )

        described_class.increment_apdex(zoekt_node_id: zoekt_node_id, task_type: task_type, duration: duration)
      end
    end
  end
end
