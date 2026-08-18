# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountCustomizedScanProfiles, feature_category: :security_testing_configuration do
  let(:expected_value) { 2 }
  let(:expected_query) do
    'SELECT COUNT("security_scan_profiles"."id") FROM "security_scan_profiles" ' \
      'WHERE "security_scan_profiles"."gitlab_recommended" = FALSE'
  end

  before do
    create_list(:security_scan_profile, 2, gitlab_recommended: false)
    create(:security_scan_profile, gitlab_recommended: true)
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' }
end
