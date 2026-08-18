# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountDistinctNamespacesWithAiToolRulesMetric, feature_category: :service_ping do
  let(:expected_query) do
    'SELECT COUNT(DISTINCT "ai_tool_rules"."namespace_id") FROM "ai_tool_rules"'
  end

  context 'with tool rules across multiple namespaces' do
    let_it_be(:group1) { create(:group) }
    let_it_be(:group2) { create(:group) }

    let_it_be(:rule1) { create(:ai_tool_rule, namespace: group1, tool_name: 'create_issue') }
    let_it_be(:rule2) { create(:ai_tool_rule, namespace: group1, tool_name: 'create_merge_request') }
    let_it_be(:rule3) { create(:ai_tool_rule, namespace: group2, tool_name: 'create_issue') }

    it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
      let(:expected_value) { 2 }
    end
  end
end
