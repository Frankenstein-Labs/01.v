# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::MetricsService, feature_category: :global_search do
  let(:service) { described_class.new(metric.to_s) }
  let(:logger) { instance_double(::Search::Zoekt::Logger) }

  subject(:execute) { service.execute }

  before do
    allow(Search::Zoekt::Logger).to receive(:build).and_return(logger)
  end

  describe '.execute' do
    let(:metric) { :foo }

    it 'executes the metric' do
      expect(described_class).to receive(:new).with(metric).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(metric)
    end
  end

  describe '#execute' do
    let(:metric) { :foo }

    it 'raises an exception when unknown metric is provided' do
      expect { service.execute }.to raise_error(ArgumentError)
    end

    it 'raises an exception when the metric is not implemented' do
      stub_const('::Search::Zoekt::MetricsService::METRICS', [:foo])

      expect { service.execute }.to raise_error(NotImplementedError)
    end
  end

  describe '#node_metrics' do
    let(:metric) { :node_metrics }
    let_it_be(:node) { create(:zoekt_node, :enough_free_space) }

    before do
      allow(logger).to receive(:info) # avoid a flaky test if there are multiple zoekt nodes
    end

    it 'logs zoekt metadata and tasks info for nodes' do
      create(:zoekt_index, zoekt_enabled_namespace: create(:zoekt_enabled_namespace), node: node)
      create_list(:zoekt_task, 4, :pending, node: node)
      create(:zoekt_task, :done, node: node)
      create(:zoekt_task, :orphaned, node: node)
      create_list(:zoekt_task, 2, :failed, node: node)

      expect(logger).to receive(:info).with(a_hash_including(
        'class' => described_class.name,
        'meta' => a_hash_including(node.metadata_json.stringify_keys),
        'enabled_namespaces_count' => 1,
        'indices_count' => node.indices.count,
        'task_count_pending' => 4,
        'task_count_failed' => 2,
        'task_count_done' => 1,
        'task_count_orphaned' => 1,
        'metric' => :node_metrics
      ))

      execute
    end
  end

  describe '#indices_metrics' do
    let(:metric) { :indices_metrics }

    before do
      allow(logger).to receive(:info) # avoid a flaky test if there are multiple zoekt nodes
    end

    it 'logs info for zoekt indices' do
      allow(::Search::Zoekt::Index).to receive_message_chain(
        :with_stale_used_storage_bytes_updated_at, :count
      ).and_return(8675309)

      expect(logger).to receive(:info).with(a_hash_including(
        'class' => described_class.name,
        'meta.zoekt.with_stale_used_storage_bytes_updated_at' => 8675309,
        'metric' => :indices_metrics
      ))

      execute
    end
  end
end
