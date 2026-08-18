# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::SymbolsPasswordComplexityRequiredMetric, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  where(:password_symbol_required, :expected_value) do
    true  | true
    false | false
  end

  with_them do
    before do
      stub_application_setting(password_symbol_required: password_symbol_required)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
