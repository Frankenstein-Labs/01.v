# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::AdvancedSearch::BuildFlavorMetric,
  feature_category: :global_search do
  let(:mock_es_helper) { instance_double(Search::Elastic::Helper, server_info: { build_flavor: 'default' }) }

  before do
    allow(Search::Elastic::Helper).to receive(:default).and_return(mock_es_helper)
  end

  context 'when elasticsearch_indexing is disabled' do
    before do
      stub_ee_application_setting(elasticsearch_indexing: false)
    end

    it_behaves_like 'a correct instrumented metric value', { data_source: 'system' } do
      let(:expected_value) { 'NA' }
    end
  end

  context 'when elasticsearch_indexing is enabled' do
    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    it_behaves_like 'a correct instrumented metric value', { data_source: 'system' } do
      let(:expected_value) { 'default' }
    end

    context 'when build_flavor is not returned by server' do
      let(:mock_es_helper) { instance_double(Search::Elastic::Helper, server_info: {}) }

      it_behaves_like 'a correct instrumented metric value', { data_source: 'system' } do
        let(:expected_value) { 'unknown' }
      end
    end
  end
end
