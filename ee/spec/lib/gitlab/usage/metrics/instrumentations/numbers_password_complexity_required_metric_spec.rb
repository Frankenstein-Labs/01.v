# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::NumbersPasswordComplexityRequiredMetric, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  where(:password_number_required, :expected_value) do
    true  | true
    false | false
  end

  with_them do
    before do
      stub_application_setting(password_number_required: password_number_required)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
