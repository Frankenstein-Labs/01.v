# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::FoundationalFlowEnabledCountsMetric,
  feature_category: :service_ping do
  let(:metric) { described_class.new({ time_frame: 'none', data_source: 'database' }) }

  subject(:value) { metric.value }

  it 'includes all foundational flows in the result' do
    expected_references = ::Ai::Catalog::FoundationalFlow.all.map(&:foundational_flow_reference)

    expect(value.keys).to match_array(expected_references)
  end

  it 'counts namespaces with each flow enabled' do
    flow_reference = ::Ai::Catalog::FoundationalFlow.all.first.foundational_flow_reference

    create(:ai_catalog_enabled_foundational_flow, :for_namespace,
      catalog_item: create(:ai_catalog_item, :with_foundational_flow_reference,
        foundational_flow_reference: flow_reference))
    create(:ai_catalog_enabled_foundational_flow, :for_namespace,
      catalog_item: create(:ai_catalog_item, :with_foundational_flow_reference,
        foundational_flow_reference: flow_reference))
    # project-level should not be counted
    create(:ai_catalog_enabled_foundational_flow, :for_project,
      catalog_item: create(:ai_catalog_item, :with_foundational_flow_reference,
        foundational_flow_reference: flow_reference))

    expect(value[flow_reference]).to eq(2)
  end

  it 'returns zero for flows not enabled in any namespace' do
    flow_reference = ::Ai::Catalog::FoundationalFlow.all.first.foundational_flow_reference

    expect(value[flow_reference]).to eq(0)
  end
end
