# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::BlockSeatOverageEnabledMetric, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  where(:seat_control, :expected_value) do
    0  | false
    1  | false
    2  | true
  end

  with_them do
    before do
      stub_application_setting(seat_control: seat_control)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
