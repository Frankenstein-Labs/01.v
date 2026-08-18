# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountProjectsWithCustomizedScanProfiles, feature_category: :security_testing_configuration do
  let(:expected_value) { 2 }
  let(:expected_query) do
    'SELECT COUNT(DISTINCT "security_scan_profiles_projects"."project_id") ' \
      'FROM "security_scan_profiles_projects" ' \
      'INNER JOIN "security_scan_profiles" ' \
      'ON "security_scan_profiles"."id" = "security_scan_profiles_projects"."security_scan_profile_id" ' \
      'WHERE "security_scan_profiles"."gitlab_recommended" = FALSE'
  end

  before do
    customized = create(:security_scan_profile, gitlab_recommended: false)
    recommended = create(:security_scan_profile, gitlab_recommended: true)

    # Two distinct projects using a customized profile -> counted.
    create(:security_scan_profile_project, scan_profile: customized)
    create(:security_scan_profile_project, scan_profile: customized)

    # A project using only a recommended profile -> not counted.
    create(:security_scan_profile_project, scan_profile: recommended)
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' }
end
