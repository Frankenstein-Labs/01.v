# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::ToolApprovalForSessionEnabledMetric,
  feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  where(:tool_approval_for_session_enabled, :expected_value) do
    false | false
    true  | true
  end

  with_them do
    before do
      stub_application_setting(tool_approval_for_session_enabled: tool_approval_for_session_enabled)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
