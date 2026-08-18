# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountDistinctNamespacesWithProjectAiToolRulesMetric, feature_category: :service_ping do
  let(:expected_query) do
    'SELECT COUNT(DISTINCT "ai_tool_rules"."namespace_id") FROM "ai_tool_rules" ' \
      'WHERE "ai_tool_rules"."project_id" IS NOT NULL'
  end

  context 'with namespace-level and project-scoped rules' do
    let_it_be(:group1) { create(:group) }
    let_it_be(:group2) { create(:group) }
    let_it_be(:project) { create(:project, group: group2) }

    let_it_be(:namespace_rule1) { create(:ai_tool_rule, namespace: group1, tool_name: 'create_issue') }
    let_it_be(:namespace_rule2) { create(:ai_tool_rule, namespace: group1, tool_name: 'create_merge_request') }
    let_it_be(:project_rule) do
      create(:ai_tool_rule, namespace: group2, project: project, tool_name: 'create_issue')
    end

    it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
      let(:expected_value) { 1 }
    end
  end
end
