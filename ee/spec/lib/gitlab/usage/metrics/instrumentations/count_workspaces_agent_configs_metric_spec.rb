# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountWorkspacesAgentConfigsMetric, feature_category: :workspaces do
  before do
    create_list(:workspaces_agent_config, 2)
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
    let(:expected_value) { 2 }
    let(:expected_query) do
      'SELECT COUNT(DISTINCT "workspaces_agent_configs"."cluster_agent_id") ' \
        'FROM "workspaces_agent_configs"'
    end
  end
end
