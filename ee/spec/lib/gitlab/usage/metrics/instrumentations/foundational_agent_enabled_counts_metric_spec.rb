# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Usage::Metrics::Instrumentations::FoundationalAgentEnabledCountsMetric,
  feature_category: :service_ping do
  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- specs create the instance AI settings default row

  let(:metric) { described_class.new({ time_frame: 'none', data_source: 'database' }) }

  subject(:value) { metric.value }

  context 'when instance default is enabled' do
    before do
      create(:ai_settings, organization: default_organization, foundational_agents_default_enabled: true)
    end

    it 'counts organizations with explicit enabled=true plus those inheriting the default' do
      org_with_explicit_enabled = create(:organization)
      org_with_explicit_disabled = create(:organization)
      _org_inheriting_default = create(:organization)

      agent_reference = ::Ai::FoundationalChatAgent.all.reject(&:duo_chat?).first.reference

      create(:organization_foundational_agents_status,
        organization: org_with_explicit_enabled,
        reference: agent_reference,
        enabled: true)

      create(:organization_foundational_agents_status,
        organization: org_with_explicit_disabled,
        reference: agent_reference,
        enabled: false)

      # 1 explicit + 2 inheriting (including the default organization; org_with_explicit_disabled opted out)
      expect(value[agent_reference]).to eq(3)
    end
  end

  context 'when instance default is disabled' do
    before do
      create(:ai_settings, organization: default_organization, foundational_agents_default_enabled: false)
    end

    it 'only counts organizations with an explicit enabled=true record' do
      org_with_explicit_enabled = create(:organization)
      _org_with_no_record = create(:organization)

      agent_reference = ::Ai::FoundationalChatAgent.all.reject(&:duo_chat?).first.reference

      create(:organization_foundational_agents_status,
        organization: org_with_explicit_enabled,
        reference: agent_reference,
        enabled: true)

      expect(value[agent_reference]).to eq(1)
    end
  end

  it 'includes all non-chat agents in the result' do
    create(:ai_settings, organization: default_organization)

    expected_references = ::Ai::FoundationalChatAgent.all.reject(&:duo_chat?).map(&:reference)

    expect(value.keys).to match_array(expected_references)
  end

  it 'does not include the chat agent' do
    create(:ai_settings, organization: default_organization)

    expect(value.keys).not_to include('chat')
  end
end
