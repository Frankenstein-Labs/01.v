# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::AutoDuoCodeReviewEnabledMetric,
  feature_category: :plan_provisioning do
  using RSpec::Parameterized::TableSyntax

  where(:auto_duo_code_review_enabled, :expected_value) do
    false | false
    true  | true
  end

  with_them do
    before do
      stub_application_setting(auto_duo_code_review_enabled: auto_duo_code_review_enabled)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
