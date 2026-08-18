# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountZoektNodesMetric, feature_category: :global_search do
  let_it_be(:_online) { create_list(:zoekt_node, 3) }
  let_it_be(:_offline) { create_list(:zoekt_node, 2, :offline) }

  let(:expected_value) { 3 }

  it_behaves_like 'a correct instrumented metric value', { time_frame: 'all', data_source: 'database' }

  describe '#available?' do
    subject { described_class.new(time_frame: 'all', options: { data_source: 'database' }).available? }

    context 'when license zoekt_code_search is not available' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when license zoekt_code_search is available' do
      before do
        stub_licensed_features(zoekt_code_search: true)
      end

      it { is_expected.to be(true) }
    end
  end
end
