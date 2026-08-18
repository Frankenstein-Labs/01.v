# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::ZoektSearchEnabledMetric, feature_category: :service_ping do
  describe '#value' do
    context 'when zoekt_search_enabled is true' do
      let(:expected_value) { true }

      before do
        stub_ee_application_setting(zoekt_search_enabled: true)
      end

      it_behaves_like 'a correct instrumented metric value', { time_frame: 'all', data_source: 'system' }
    end

    context 'when zoekt_search_enabled is false' do
      let(:expected_value) { false }

      before do
        stub_ee_application_setting(zoekt_search_enabled: false)
      end

      it_behaves_like 'a correct instrumented metric value', { time_frame: 'all', data_source: 'system' }
    end
  end

  describe '#available?' do
    subject { described_class.new(time_frame: 'none', options: { data_source: 'system' }).available? }

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
