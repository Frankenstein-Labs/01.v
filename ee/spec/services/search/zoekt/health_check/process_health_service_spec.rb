# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::HealthCheck::ProcessHealthService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger) }

  let(:healthy_indexer) do
    {
      'mmap_current' => 1000,
      'mmap_max' => 65530,
      'restarts_1m' => 0,
      'restarts_5m' => 0,
      'restarts_15m' => 0,
      'rss_bytes' => 268_435_456,
      'uptime_seconds' => 3600
    }
  end

  let(:healthy_webserver) do
    {
      'mmap_current' => 2000,
      'mmap_max' => 65530,
      'restarts_1m' => 0,
      'restarts_5m' => 0,
      'restarts_15m' => 0,
      'rss_bytes' => 536_870_912,
      'uptime_seconds' => 7200,
      'shards_loaded' => 10
    }
  end

  let(:healthy_process_health) do
    { 'indexer' => healthy_indexer, 'webserver' => healthy_webserver }
  end

  before do
    allow(logger).to receive(:info)
  end

  describe '#execute' do
    it 'logs a blank line and the section header' do
      expect(logger).to receive(:info).with("").ordered
      expect(logger).to receive(:info).with(include('Process Health:')).ordered

      service.execute
    end

    context 'when no online nodes exist' do
      it 'returns healthy status with no warnings or errors', :aggregate_failures do
        result = service.execute

        expect(result[:status]).to eq(:healthy)
        expect(result[:warnings]).to be_empty
        expect(result[:errors]).to be_empty
      end

      it 'logs that there are no online nodes to check' do
        service.execute

        expect(logger).to have_received(:info).with(include('No online nodes to check process health'))
      end
    end

    context 'when online nodes exist' do
      let_it_be_with_reload(:node) { create(:zoekt_node, :for_search) }

      context 'when a node has no process health data (older indexer)' do
        before do
          node.update!(metadata: { 'name' => 'node-1' })
        end

        it 'returns healthy status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:healthy)
          expect(result[:warnings]).to be_empty
          expect(result[:errors]).to be_empty
        end

        it 'logs N/A for the node' do
          service.execute

          expect(logger).to have_received(:info).with(include('Node').and(include('N/A')))
        end
      end

      context 'when process_health is present but indexer is missing' do
        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => { 'webserver' => healthy_webserver }),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns healthy status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:healthy)
          expect(result[:warnings]).to be_empty
          expect(result[:errors]).to be_empty
        end

        it 'logs N/A for the indexer' do
          service.execute

          expect(logger).to have_received(:info).with(include('Indexer: N/A'))
        end
      end

      context 'when process_health is present but webserver is missing' do
        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => { 'indexer' => healthy_indexer }),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns healthy status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:healthy)
          expect(result[:warnings]).to be_empty
          expect(result[:errors]).to be_empty
        end

        it 'logs N/A for the webserver' do
          service.execute

          expect(logger).to have_received(:info).with(include('Webserver: N/A'))
        end
      end

      context 'when a node has healthy process health data' do
        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => healthy_process_health),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns healthy status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:healthy)
          expect(result[:warnings]).to be_empty
          expect(result[:errors]).to be_empty
        end

        it 'logs healthy status for both processes', :aggregate_failures do
          service.execute

          expect(logger).to have_received(:info).with(include('Indexer: healthy'))
          expect(logger).to have_received(:info).with(include('Webserver: healthy'))
        end
      end

      context 'when indexer has a single recent restart (restarts_15m == 1)' do
        let(:process_health) do
          {
            'indexer' => healthy_indexer.merge('restarts_15m' => 1, 'uptime_seconds' => 300),
            'webserver' => healthy_webserver
          }
        end

        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => process_health),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns degraded status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:degraded)
          expect(result[:warnings]).to include(include('recent restart'))
          expect(result[:errors]).to be_empty
        end

        it 'logs a warning for the indexer restart' do
          service.execute

          expect(logger).to have_received(:info).with(include('Indexer: recent restart'))
        end
      end

      context 'when webserver has a single recent restart (restarts_15m == 1)' do
        let(:process_health) do
          {
            'indexer' => healthy_indexer,
            'webserver' => healthy_webserver.merge(
              'restarts_5m' => 1,
              'restarts_15m' => 1,
              'uptime_seconds' => 300
            )
          }
        end

        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => process_health),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns degraded status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:degraded)
          expect(result[:warnings]).to include(include('recent restart'))
          expect(result[:errors]).to be_empty
        end
      end

      context 'when indexer mmap usage is >= 80% (warning threshold)' do
        let(:process_health) do
          # 52424 / 65530 ~= 80%
          { 'indexer' => healthy_indexer.merge('mmap_current' => 52_424), 'webserver' => healthy_webserver }
        end

        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => process_health),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns degraded status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:degraded)
          expect(result[:warnings]).to include(include('mmap usage high'))
          expect(result[:errors]).to be_empty
        end
      end

      context 'when webserver mmap usage is >= 80% (warning threshold)' do
        let(:process_health) do
          # 52424 / 65530 ~= 80%
          { 'indexer' => healthy_indexer, 'webserver' => healthy_webserver.merge('mmap_current' => 52_424) }
        end

        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => process_health),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns degraded status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:degraded)
          expect(result[:warnings]).to include(include('webserver mmap usage high'))
          expect(result[:errors]).to be_empty
        end

        it 'logs a warning for the webserver mmap usage' do
          service.execute

          expect(logger).to have_received(:info).with(include('Webserver: mmap high'))
        end
      end

      context 'when indexer is crashlooping (restarts_15m >= 2)' do
        let(:process_health) do
          {
            'indexer' => healthy_indexer.merge(
              'restarts_1m' => 2,
              'restarts_5m' => 2,
              'restarts_15m' => 2,
              'uptime_seconds' => 60
            ),
            'webserver' => healthy_webserver
          }
        end

        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => process_health),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns unhealthy status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include(include('crashlooping'))
          expect(result[:warnings]).to be_empty
        end

        it 'logs an error for the crashlooping indexer' do
          service.execute

          expect(logger).to have_received(:info).with(include('Indexer: crashlooping'))
        end
      end

      context 'when webserver is crashlooping (restarts_15m >= 2)' do
        let(:process_health) do
          {
            'indexer' => healthy_indexer,
            'webserver' => healthy_webserver.merge(
              'restarts_1m' => 3,
              'restarts_5m' => 3,
              'restarts_15m' => 3,
              'uptime_seconds' => 30,
              'shards_loaded' => 0
            )
          }
        end

        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => process_health),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns unhealthy status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include(include('crashlooping'))
        end
      end

      context 'when indexer mmap usage is >= 95% (critical threshold)' do
        let(:process_health) do
          # 62254 / 65530 ~= 95%
          { 'indexer' => healthy_indexer.merge('mmap_current' => 62_254), 'webserver' => healthy_webserver }
        end

        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => process_health),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns unhealthy status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include(include('indexer mmap usage critical'))
        end
      end

      context 'when webserver mmap usage is >= 95% (critical threshold)' do
        let(:process_health) do
          # 62254 / 65530 ~= 95%
          { 'indexer' => healthy_indexer, 'webserver' => healthy_webserver.merge('mmap_current' => 62_254) }
        end

        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => process_health),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns unhealthy status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include(include('webserver mmap usage critical'))
          expect(result[:warnings]).to be_empty
        end

        it 'logs an error for the webserver mmap usage' do
          service.execute

          expect(logger).to have_received(:info).with(include('Webserver: mmap critical'))
        end
      end

      context 'when webserver is offline' do
        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => healthy_process_health),
            webserver_last_seen_at: 2.days.ago
          )
        end

        it 'returns unhealthy status', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include(include('offline'))
        end

        it 'logs an error for the offline webserver' do
          service.execute

          expect(logger).to have_received(:info).with(include('offline')).at_least(:once)
        end
      end

      context 'when webserver_last_seen_at is nil (webserver never reported)' do
        let(:process_health) do
          { 'indexer' => healthy_indexer }
        end

        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => process_health),
            webserver_last_seen_at: nil
          )
        end

        it 'returns healthy status (nil means never reported, not stale)', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:healthy)
          expect(result[:errors]).to be_empty
        end
      end

      context 'with multiple nodes having mixed health states' do
        let(:crashlooping_process_health) do
          {
            'indexer' => healthy_indexer.merge(
              'restarts_1m' => 3,
              'restarts_5m' => 3,
              'restarts_15m' => 3,
              'uptime_seconds' => 30
            ),
            'webserver' => healthy_webserver
          }
        end

        let_it_be_with_reload(:node2) { create(:zoekt_node, :for_search) }

        before do
          node.update!(
            metadata: node.metadata.merge('process_health' => healthy_process_health),
            webserver_last_seen_at: Time.zone.now
          )
          node2.update!(
            metadata: node2.metadata.merge('process_health' => crashlooping_process_health),
            webserver_last_seen_at: Time.zone.now
          )
        end

        it 'returns unhealthy status (worst case wins)', :aggregate_failures do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include(include('crashlooping'))
        end
      end
    end
  end

  describe '.execute' do
    it 'creates instance and calls execute', :aggregate_failures do
      expect(described_class).to receive(:new).with(logger: logger).and_call_original

      result = described_class.execute(logger: logger)

      expect(result).to include(:status, :warnings, :errors)
    end
  end
end
