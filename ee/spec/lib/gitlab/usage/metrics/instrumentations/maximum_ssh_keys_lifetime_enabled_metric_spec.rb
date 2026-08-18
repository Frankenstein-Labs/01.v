# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::MaximumSshKeysLifetimeEnabledMetric, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  where(:max_ssh_key_lifetime, :expected_value) do
    10  | 10
    nil | nil
  end

  with_them do
    before do
      stub_application_setting(max_ssh_key_lifetime: max_ssh_key_lifetime)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
