# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::DuoWorkflows::EnablementType, feature_category: :duo_agent_platform do
  specify { expect(described_class.graphql_name).to eq('DuoWorkflowEnablement') }

  it 'has the expected fields' do
    expected_fields = %i[
      create_duo_workflow_for_ci_allowed
      enabled
      checks
      enabled_foundational_flows
      foundational_flows_enabled
      remote_flows_enabled
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  it 'exposes enabledFoundationalFlows as nullable list of strings' do
    expect(described_class.fields['enabledFoundationalFlows'].type.to_type_signature).to eq('[String!]')
  end

  describe 'authorization scopes' do
    it 'allows api, read_api and ai_workflows token scopes' do
      expect(described_class.authorization_scopes).to match_array([:api, :read_api, :ai_workflows])
    end
  end

  describe 'field scopes' do
    it 'restricts enabledFoundationalFlows to api, read_api and ai_workflows scopes' do
      expect(described_class.fields['enabledFoundationalFlows'].scopes)
        .to match_array([:api, :read_api, :ai_workflows])
    end

    it 'restricts foundationalFlowsEnabled to api, read_api and ai_workflows scopes' do
      expect(described_class.fields['foundationalFlowsEnabled'].scopes)
        .to match_array([:api, :read_api, :ai_workflows])
    end
  end
end
