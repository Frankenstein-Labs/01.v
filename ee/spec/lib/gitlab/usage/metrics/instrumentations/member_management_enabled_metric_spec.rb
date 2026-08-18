# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::MemberManagementEnabledMetric, feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  where(:enable_member_promotion_management, :expected_value) do
    true  | true
    false | false
  end

  with_them do
    before do
      stub_application_setting(enable_member_promotion_management: enable_member_promotion_management)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
