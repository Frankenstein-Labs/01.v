# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::HealthCheck::NodeStatusService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger) }

  before do
    allow(logger).to receive(:info)
  end

  describe '#execute' do
    it 'logs a blank line and the section header' do
      expect(logger).to receive(:info).with("").ordered
      expect(logger).to receive(:info).with(include('Node Status:')).ordered

      service.execute
    end

    context 'when no nodes are configured' do
      it 'returns unhealthy status with configuration error' do
        result = service.execute

        expect(result[:status]).to eq(:unhealthy)
        expect(result[:errors]).to include('Configure and deploy Zoekt nodes to enable exact code search')
        expect(result[:warnings]).to be_empty
      end

      it 'logs no nodes configured error' do
        expect(logger).to receive(:info).with(include('✗ No nodes configured'))

        service.execute
      end
    end

    context 'when all nodes are offline' do
      let_it_be(:node1) { create(:zoekt_node, :for_search, :offline) }
      let_it_be(:node2) { create(:zoekt_node, :for_search, :offline) }
      let_it_be(:node3) { create(:zoekt_node, :for_search, :offline) }

      it 'returns unhealthy status with connectivity error' do
        result = service.execute

        expect(result[:status]).to eq(:unhealthy)
        expect(result[:errors]).to include('Check Zoekt node connectivity and restart offline services')
        expect(result[:warnings]).to be_empty
      end

      it 'logs all nodes offline error' do
        expect(logger).to receive(:info).with(include('✗ 3 of 3 nodes offline'))

        service.execute
      end
    end

    context 'when some nodes are offline' do
      let_it_be(:online_node1) { create(:zoekt_node, :for_search) }
      let_it_be(:online_node2) { create(:zoekt_node, :for_search) }
      let_it_be(:offline_node) { create(:zoekt_node, :for_search, :offline) }

      it 'returns degraded status with warning' do
        result = service.execute

        expect(result[:status]).to eq(:degraded)
        expect(result[:errors]).to be_empty
        expect(result[:warnings]).to include('Investigate 1 offline nodes and restore connectivity')
      end

      it 'logs partial online status' do
        expect(logger).to receive(:info).with(include('⚠ 2 of 3 nodes online'))
        expect(logger).to receive(:info).with(include('⚠ WARNING: Nodes offline'))

        service.execute
      end
    end

    context 'when all nodes are online' do
      let_it_be(:node1) { create(:zoekt_node, :for_search) }
      let_it_be(:node2) { create(:zoekt_node, :for_search) }

      it 'returns healthy status when storage is healthy' do
        result = service.execute

        expect(result[:status]).to eq(:healthy)
        expect(result[:errors]).to be_empty
        expect(result[:warnings]).to be_empty
      end

      it 'logs all nodes online and healthy storage' do
        expect(logger).to receive(:info).with(include('✓ 2 of 2 nodes online'))
        expect(logger).to receive(:info).with(include('✓ Storage usage healthy'))

        service.execute
      end
    end

    context 'when nodes have high storage usage' do
      context 'with critical storage usage' do
        let_it_be(:critical_node) { create(:zoekt_node, :for_search, :watermark_critical) }
        let_it_be(:normal_node) { create(:zoekt_node, :for_search, :watermark_normal) }

        it 'returns unhealthy status' do
          result = service.execute

          expect(result[:status]).to eq(:unhealthy)
          expect(result[:errors]).to include('Add nodes or clean up storage on 1 nodes with critical usage')
        end

        it 'logs critical storage usage' do
          expect(logger).to receive(:info).with(include('✗ Critical storage usage on 1 nodes'))

          service.execute
        end
      end

      context 'with high storage usage' do
        let_it_be(:high_node1) { create(:zoekt_node, :for_search, :watermark_high) }
        let_it_be(:high_node2) { create(:zoekt_node, :for_search, :watermark_high) }

        it 'returns degraded status' do
          result = service.execute

          expect(result[:status]).to eq(:degraded)
          expect(result[:warnings]).to include(
            'Monitor and consider adding nodes or expanding storage on 2 nodes with high usage'
          )
        end

        it 'logs high storage usage' do
          expect(logger).to receive(:info).with(include('⚠ High storage usage on 2 nodes'))

          service.execute
        end
      end
    end
  end

  describe '.execute' do
    it 'creates instance and calls execute' do
      expect(described_class).to receive(:new).with(logger: logger).and_call_original

      described_class.execute(logger: logger)
    end
  end
end
