# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::ProcessHealth, feature_category: :global_search do
  let(:healthy_indexer) do
    {
      'mmap_current' => 100,
      'mmap_max' => 1000,
      'restarts_1m' => 0,
      'restarts_5m' => 0,
      'restarts_15m' => 0,
      'rss_bytes' => 268_435_456,
      'uptime_seconds' => 3600
    }
  end

  let(:healthy_webserver) do
    {
      'mmap_current' => 100,
      'mmap_max' => 1000,
      'restarts_1m' => 0,
      'restarts_5m' => 0,
      'restarts_15m' => 0,
      'rss_bytes' => 536_870_912,
      'uptime_seconds' => 3600,
      'shards_loaded' => 10
    }
  end

  let(:process_health) { { 'indexer' => healthy_indexer, 'webserver' => healthy_webserver } }
  let(:node) do
    create(:zoekt_node,
      metadata: { 'name' => 'node-1', 'version' => '1.16.0', 'process_health' => process_health },
      webserver_last_seen_at: Time.zone.now
    )
  end

  before do
    allow(described_class).to receive(:active?).and_return(true)
  end

  describe '.active?' do
    before do
      allow(described_class).to receive(:active?).and_call_original
    end

    it 'delegates to Node.all_at_least_version? with MIN_VERSION' do
      expect(::Search::Zoekt::Node).to receive(:all_at_least_version?).with(described_class::MIN_VERSION)
      described_class.active?
    end
  end

  describe '.unhealthy?' do
    subject { described_class.unhealthy?(node) }

    context 'when not active (older node versions)' do
      before do
        allow(described_class).to receive(:active?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when all metrics are healthy' do
      it { is_expected.to be(false) }
    end

    context 'when indexer restarts_15m equals the configured maximum' do
      before do
        process_health['indexer']['restarts_15m'] = ::Search::Zoekt::Settings.max_restarts_15m
      end

      it { is_expected.to be(false) }
    end

    context 'when indexer restarts_15m exceeds the configured maximum' do
      before do
        process_health['indexer']['restarts_15m'] = ::Search::Zoekt::Settings.max_restarts_15m + 1
      end

      it { is_expected.to be(true) }
    end

    context 'when webserver restarts_15m exceeds the configured maximum' do
      before do
        process_health['webserver']['restarts_15m'] = ::Search::Zoekt::Settings.max_restarts_15m + 1
      end

      it { is_expected.to be(true) }
    end

    context 'when max_restarts_15m is 0 (strict mode)' do
      before do
        allow(::Search::Zoekt::Settings).to receive(:max_restarts_15m).and_return(0)
      end

      context 'and the node has 0 restarts' do
        it { is_expected.to be(false) }
      end

      context 'and the node has 1 restart in the last 15 minutes' do
        before do
          process_health['indexer']['restarts_15m'] = 1
        end

        it { is_expected.to be(true) }
      end
    end

    context 'when indexer mmap usage is >= 95%' do
      before do
        process_health['indexer']['mmap_current'] = 960
        process_health['indexer']['mmap_max'] = 1000
      end

      it { is_expected.to be(true) }
    end

    context 'when webserver mmap usage is exactly 95%' do
      before do
        process_health['webserver']['mmap_current'] = 950
        process_health['webserver']['mmap_max'] = 1000
      end

      it { is_expected.to be(true) }
    end

    context 'when webserver_last_seen_at is stale' do
      before do
        node.update!(webserver_last_seen_at: 2.days.ago)
      end

      it { is_expected.to be(true) }
    end

    context 'when webserver_last_seen_at is nil (never reported yet)' do
      before do
        node.update!(webserver_last_seen_at: nil)
      end

      # When ProcessHealth is active, a node that has never reported webserver
      # metrics is not safe to route to - treat it as stale/unhealthy.
      it { is_expected.to be(true) }
    end

    context 'when mmap_max is 0 (invalid)' do
      before do
        process_health['indexer']['mmap_max'] = 0
        process_health['indexer']['mmap_current'] = 999_999
      end

      it { is_expected.to be(false) }
    end

    context 'when process_health is missing entirely' do
      before do
        node.metadata.delete('process_health')
      end

      it { is_expected.to be(false) }
    end
  end
end
