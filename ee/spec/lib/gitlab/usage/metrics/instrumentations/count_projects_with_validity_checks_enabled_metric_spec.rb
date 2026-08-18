# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsWithValidityChecksEnabledMetric, feature_category: :service_ping do
  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' } do
    let(:expected_value) { 3 }
    let(:expected_query) do
      "SELECT COUNT(\"project_security_settings\".\"project_id\") FROM \"project_security_settings\" " \
        "WHERE \"project_security_settings\".\"validity_checks_enabled\" = TRUE"
    end

    before do
      projects = create_list(:project, 3)
      projects.each { |project| project.security_setting.update!(validity_checks_enabled: true) }
      create(:project)
    end
  end
end
