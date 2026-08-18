# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Work item API parity', feature_category: :team_planning do
  it_behaves_like 'work item API field parity' do
    let(:extra_graphql_field_exceptions) { Set.new(%w[duo_workflow_links]) }

    let(:extra_graphql_feature_exceptions) do
      Set.new(%w[
        agent_plan
        ai_session
        test_reports
        vulnerabilities
      ])
    end

    # linked_items: REST exposes only blocking_count / blocked_by_count counts. GraphQL exposes the
    # full paginated linkedItems connection plus blocked. The connection is intentionally split off
    # into a separate REST endpoint, so the per-feature field comparison cannot match.
    let(:extra_skipped_feature_comparison) do
      Set.new(%w[health_status linked_items])
    end
  end

  it_behaves_like 'work item API create parity' do
    # GraphQL uses `status` (a GlobalID) but REST uses `status_id` (an integer). The
    # field names differ, so skip the field-name comparison for the status widget.
    let(:widget_field_skipped) { Set.new(%w[status_widget]) }
    # development_widget is exposed only on the GraphQL create mutation (links MRs to
    # the new work item); the REST create endpoint has no development feature param.
    let(:widget_exceptions) { Set.new(%w[agent_plan_widget development_widget]) }
  end

  it_behaves_like 'work item API filter parity' do
    let(:filter_parity_wip) do
      [
        'exclude_group_work_items',
        'exclude_projects',
        'requirement_legacy_widget' # Excluded as this filter option is deprecated in GQL in favor of iids
      ]
    end

    let(:not_filter_parity_wip) { %w[custom_field] }
    let(:or_filter_parity_wip) { %w[custom_field health_status_filter weight] }
  end
end
