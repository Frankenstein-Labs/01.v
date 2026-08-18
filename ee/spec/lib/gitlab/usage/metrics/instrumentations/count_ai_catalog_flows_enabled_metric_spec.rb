# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountAiCatalogFlowsEnabledMetric, feature_category: :workflow_catalog do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, organization: organization) }
  let_it_be(:group) { create(:group, organization: organization) }

  let_it_be(:flow_item) { create(:ai_catalog_flow, organization: organization) }
  let_it_be(:flow_item_two) { create(:ai_catalog_flow, organization: organization) }

  let_it_be(:enabled_project_consumer) do
    create(:ai_catalog_item_consumer,
      item: flow_item,
      project: project,
      group: nil,
      enabled: true,
      created_at: 3.weeks.ago
    )
  end

  let_it_be(:enabled_group_consumer) do
    create(:ai_catalog_item_consumer,
      item: flow_item,
      project: nil,
      group: group,
      enabled: true,
      created_at: 3.weeks.ago
    )
  end

  let_it_be(:disabled_consumers) do
    create(:ai_catalog_item_consumer,
      item: flow_item_two,
      project: project,
      group: nil,
      enabled: false,
      created_at: 3.weeks.ago
    )

    create(:ai_catalog_item_consumer,
      item: flow_item_two,
      project: nil,
      group: group,
      enabled: false,
      created_at: 3.weeks.ago
    )
  end

  context 'with no consumer_type' do
    context 'with all time frame' do
      let(:expected_value) { 2 }
      let(:expected_query) do
        "SELECT COUNT(\"ai_catalog_item_consumers\".\"id\") FROM \"ai_catalog_item_consumers\" " \
          "WHERE \"ai_catalog_item_consumers\".\"enabled\" = TRUE"
      end

      it_behaves_like 'a correct instrumented metric value and query', time_frame: 'all', options: {}
    end
  end

  context 'with invalid consumer_type' do
    it 'raises ArgumentError' do
      expect { described_class.new(time_frame: 'all', options: { consumer_type: 'invalid_type' }) }
        .to raise_error(ArgumentError, /consumer_type 'invalid_type' must be one of/)
    end
  end

  context 'with consumer_type project' do
    context 'with all time frame' do
      let(:expected_value) { 1 }
      let(:expected_query) do
        "SELECT COUNT(\"ai_catalog_item_consumers\".\"id\") FROM \"ai_catalog_item_consumers\" " \
          "WHERE \"ai_catalog_item_consumers\".\"enabled\" = TRUE " \
          "AND \"ai_catalog_item_consumers\".\"project_id\" IS NOT NULL"
      end

      it_behaves_like 'a correct instrumented metric value and query',
        time_frame: 'all',
        options: { consumer_type: 'project' }
    end
  end

  context 'with consumer_type group' do
    context 'with all time frame' do
      let(:expected_value) { 1 }
      let(:expected_query) do
        "SELECT COUNT(\"ai_catalog_item_consumers\".\"id\") FROM \"ai_catalog_item_consumers\" " \
          "WHERE \"ai_catalog_item_consumers\".\"enabled\" = TRUE " \
          "AND \"ai_catalog_item_consumers\".\"group_id\" IS NOT NULL"
      end

      it_behaves_like 'a correct instrumented metric value and query',
        time_frame: 'all',
        options: { consumer_type: 'group' }
    end
  end

  context 'when no enabled consumers exist' do
    before_all do
      Ai::Catalog::ItemConsumer.update_all(enabled: false)
    end

    let(:expected_value) { 0 }
    let(:expected_query) do
      "SELECT COUNT(\"ai_catalog_item_consumers\".\"id\") FROM \"ai_catalog_item_consumers\" " \
        "WHERE \"ai_catalog_item_consumers\".\"enabled\" = TRUE"
    end

    it_behaves_like 'a correct instrumented metric value and query', time_frame: 'all', options: {}
  end
end
