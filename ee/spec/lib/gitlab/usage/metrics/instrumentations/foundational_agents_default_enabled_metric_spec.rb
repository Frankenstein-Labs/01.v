# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::FoundationalAgentsDefaultEnabledMetric,
  feature_category: :service_ping do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- Service Ping reads the instance-wide settings row on the default organization

  where(:foundational_agents_default_enabled, :expected_value) do
    false | false
    true  | true
  end

  with_them do
    before do
      create(:ai_settings, organization: default_organization,
        foundational_agents_default_enabled: foundational_agents_default_enabled)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
