# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::CountComplianceFrameworksMetric, feature_category: :compliance_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }

  let_it_be(:namespace2) { create(:group) }
  let_it_be(:framework2) { create(:compliance_framework, namespace: namespace2) }

  let(:expected_value) { 2 }
  let(:expected_query) do
    <<~SQL.squish
      SELECT COUNT("compliance_management_frameworks"."id") FROM "compliance_management_frameworks"
    SQL
  end

  it_behaves_like 'a correct instrumented metric value and query', { time_frame: 'all', data_source: 'database' }
end
