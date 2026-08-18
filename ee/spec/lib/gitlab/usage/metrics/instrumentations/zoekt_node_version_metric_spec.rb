# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::ZoektNodeVersionMetric,
  feature_category: :global_search do
  describe '#value' do
    subject(:metric) { described_class.new({ time_frame: 'none' }) }

    context 'when there are online nodes with version metadata' do
      let_it_be(:_n1) { create(:zoekt_node, metadata: { 'name' => 'n1', 'version' => '2026.02.27-v1.9.0' }) }
      let_it_be(:_n2) { create(:zoekt_node, metadata: { 'name' => 'n2', 'version' => '2026.03.01-v1.10.0' }) }
      let_it_be(:_n3) { create(:zoekt_node, :offline, metadata: { 'name' => 'n3', 'version' => '2026.04.01-v2.0.0' }) }

      it 'returns the maximum version across online nodes' do
        expect(metric.value).to eq('2026.03.01-v1.10.0')
      end
    end

    context 'when there are no online nodes' do
      it 'returns nil' do
        expect(metric.value).to be_nil
      end
    end
  end

  describe '#available?' do
    subject(:metric) { described_class.new({ time_frame: 'none' }) }

    context 'when zoekt_code_search license is available' do
      before do
        stub_licensed_features(zoekt_code_search: true)
      end

      it { expect(metric.available?).to be(true) }
    end

    context 'when zoekt_code_search license is not available' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it { expect(metric.available?).to be(false) }
    end
  end
end
