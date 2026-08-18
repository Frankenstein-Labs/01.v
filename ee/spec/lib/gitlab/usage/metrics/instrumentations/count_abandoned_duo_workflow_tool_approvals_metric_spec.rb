# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountAbandonedDuoWorkflowToolApprovalsMetric, feature_category: :service_ping do
  let(:expected_query) do
    'SELECT COUNT("duo_workflows_workflows"."id") FROM "duo_workflows_workflows" ' \
      "WHERE \"duo_workflows_workflows\".\"status\" = 8 " \
      "AND \"duo_workflows_workflows\".\"updated_at\" < '#{24.hours.ago.to_fs(:db)}'"
  end

  context 'with workflows in various states and ages' do
    let_it_be(:abandoned_workflow) do
      create(:duo_workflows_workflow, :tool_call_approval_required, updated_at: 25.hours.ago)
    end

    let_it_be(:recent_approval_workflow) do
      create(:duo_workflows_workflow, :tool_call_approval_required, updated_at: 1.hour.ago)
    end

    let_it_be(:stale_running_workflow) do
      create(:duo_workflows_workflow, :running, updated_at: 1.week.ago)
    end

    # `let!`, not `let_it_be`: the boundary records must be created inside the shared example's
    # per-example `freeze_time`, or the second-level boundary drifts past the cutoff.
    let!(:just_past_window_workflow) do
      create(:duo_workflows_workflow, :tool_call_approval_required, updated_at: 24.hours.ago - 1.second)
    end

    let!(:exactly_at_window_boundary_workflow) do
      create(:duo_workflows_workflow, :tool_call_approval_required, updated_at: 24.hours.ago)
    end

    it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
      let(:expected_value) { 2 }
    end
  end
end
