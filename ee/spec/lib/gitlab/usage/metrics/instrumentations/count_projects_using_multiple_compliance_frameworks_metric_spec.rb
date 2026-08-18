# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsUsingMultipleComplianceFrameworksMetric, feature_category: :compliance_management do
  let_it_be(:compliance_framework_a) { create(:compliance_framework, name: 'FrameworkA') }
  let_it_be(:compliance_framework_b) { create(:compliance_framework, name: 'FrameworkB') }
  let_it_be(:project_1) { create(:project) }
  let_it_be(:project_2) { create(:project) }

  let_it_be(:framework_settings_1) do
    create(:compliance_framework_project_setting, project: project_1,
      compliance_management_framework: compliance_framework_a)
  end

  let_it_be(:framework_settings_2) do
    create(:compliance_framework_project_setting, project: project_1,
      compliance_management_framework: compliance_framework_b)
  end

  let_it_be(:framework_settings_3) do
    create(:compliance_framework_project_setting, project: project_2,
      compliance_management_framework: compliance_framework_b)
  end

  let(:expected_value) { 1 }
  let(:expected_query) do
    'SELECT COUNT(DISTINCT "project_compliance_framework_settings"."project_id") ' \
    'FROM "project_compliance_framework_settings" INNER JOIN (
                SELECT project_id
                FROM project_compliance_framework_settings
                GROUP BY project_id
                HAVING COUNT(*) > 1
              ) settings ON project_compliance_framework_settings.project_id = settings.project_id'
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' }
end
