# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::AiAuditEventsStreamingEnabledMetric,
  feature_category: :duo_agent_platform do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- instance AI settings are stored on the default organization

  where(:ai_audit_events_streaming_enabled, :expected_value) do
    false | false
    true  | true
  end

  with_them do
    before do
      ::Ai::Setting.for_organization(default_organization)
        .update!(ai_audit_events_streaming_enabled: ai_audit_events_streaming_enabled)
    end

    it_behaves_like 'a correct instrumented metric value', { time_frame: 'none' }
  end
end
