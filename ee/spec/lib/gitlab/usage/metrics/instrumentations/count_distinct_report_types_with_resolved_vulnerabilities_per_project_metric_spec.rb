# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountDistinctReportTypesWithResolvedVulnerabilitiesPerProjectMetric, feature_category: :service_ping do
  let(:start) { 30.days.ago.to_fs(:db) }
  let(:finish) { 2.days.ago.to_fs(:db) }

  let_it_be(:group_with_resolutions) { create(:group) }
  let_it_be(:child_group_with_resolutions) { create(:group, parent: group_with_resolutions) }
  let_it_be(:group_without_resolutions) { create(:group) }

  let_it_be(:project_with_two_resolutions) { create(:project, group: group_with_resolutions) }
  let_it_be(:project_with_one_resolution) { create(:project, group: child_group_with_resolutions) }
  let_it_be(:project_with_no_resolutions) { create(:project, group: group_without_resolutions) }
  let(:expected_value) { 3 }
  let(:expected_query) do
    "SELECT COUNT(*) FROM (" \
      "SELECT DISTINCT \"vulnerability_reads\".\"project_id\", \"vulnerability_reads\".\"report_type\" FROM " \
      "\"vulnerability_reads\" INNER JOIN vulnerability_state_transitions\n                  " \
      "ON vulnerability_state_transitions.vulnerability_id = vulnerability_reads.vulnerability_id " \
      "WHERE \"vulnerability_state_transitions\".\"to_state\" = 3 AND " \
      "\"vulnerability_state_transitions\".\"created_at\" BETWEEN '#{start}' AND '#{finish}' " \
      "GROUP BY \"vulnerability_reads\".\"project_id\", \"vulnerability_reads\".\"report_type\") subquery"
  end

  before do
    create(:vulnerability, :with_read, :resolved, :sast,
      :with_state_transition, to_state: :resolved,  created_at: 7.days.ago, project: project_with_two_resolutions)
    create(:vulnerability, :with_read, :resolved, :sast,
      :with_state_transition, to_state: :resolved,  created_at: 7.days.ago, project: project_with_two_resolutions)
    create(:vulnerability, :with_read, :resolved, :api_fuzzing,
      :with_state_transition, to_state: :resolved,  created_at: 7.days.ago, project: project_with_two_resolutions)

    create(:vulnerability, :with_read, :resolved, :sast,
      :with_state_transition, to_state: :resolved,  created_at: 7.days.ago, project: project_with_one_resolution)
    create(:vulnerability, :with_read, :detected, :dast, created_at: 7.days.ago,
      project: project_with_one_resolution)

    create(:vulnerability, :with_read, :detected, :dast, created_at: 7.days.ago,
      project: project_with_no_resolutions)
  end

  it_behaves_like 'a correct instrumented database query execution value',
    { time_frame: '28d', data_source: 'database' }
  it_behaves_like 'a correct instrumented metric value and query', { time_frame: '28d', data_source: 'database' }
end
