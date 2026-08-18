# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountRootNamespaceScanProfiles, feature_category: :security_testing_configuration do
  let_it_be(:security_scan_profile) { create(:security_scan_profile) }

  let(:expected_value) { 1 }
  let(:expected_query) do
    'SELECT COUNT(DISTINCT "security_scan_profiles"."namespace_id") FROM "security_scan_profiles"'
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all' }
end
