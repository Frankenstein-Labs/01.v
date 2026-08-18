# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::WrappedAgentFlowBuilder, :aggregate_failures, feature_category: :workflow_catalog do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:project) { create(:project, organization: organization) }
  let_it_be(:agent) { create(:ai_catalog_agent, organization: organization, project: project) }
  let_it_be(:agent_version) { agent.versions.last }

  let(:builder) { described_class.new(agent, agent_version) }

  shared_examples "returns error response" do |expected_message|
    it "returns an error service response" do
      result = builder.execute

      expect(result).to be_error
      expect(result.message).to match_array(expected_message)
    end
  end

  describe 'validation' do
    context 'when agent is nil' do
      let(:builder) { described_class.new(nil, agent_version) }

      it_behaves_like 'returns error response', 'Agent is required'
    end

    context 'when wrong item type is passed as agent' do
      let(:flow) { build(:ai_catalog_flow, organization: organization, project: project) }
      let(:flow_version) { flow.versions.last }
      let(:builder) { described_class.new(flow, flow_version) }

      it_behaves_like 'returns error response', 'Agent is required'
    end

    context 'when agent_version is nil' do
      let(:builder) { described_class.new(agent, nil) }

      it_behaves_like 'returns error response', 'Agent version is required'
    end

    context 'when agent_version does not belong to the agent' do
      let(:other_agent) { build(:ai_catalog_agent, organization: organization, project: project) }
      let(:other_agent_version) { other_agent.versions.last }
      let(:builder) { described_class.new(agent, other_agent_version) }

      it_behaves_like 'returns error response', 'Agent version must belong to the agent'
    end

    context 'when generated flow is invalid' do
      let(:generated_flow) { build(:ai_catalog_flow) }

      before do
        allow(builder).to receive(:flow).and_return(generated_flow)
        allow(generated_flow).to receive(:valid?).and_return(false)
      end

      it_behaves_like 'returns error response', 'Generated flow is invalid: '
    end
  end

  describe 'constants' do
    it 'defines the correct generated flow version' do
      expect(described_class::GENERATED_FLOW_VERSION).to eq('1.0.0')
    end
  end

  describe '#execute' do
    subject(:execute) { builder.execute }

    let(:generated_flow) { execute.payload[:flow] }

    it 'returns a flow item with the correct attributes' do
      flow = generated_flow

      expect(flow).to be_a(::Ai::Catalog::Item)
      expect(flow.item_type).to eq(::Ai::Catalog::Item::FLOW_TYPE.to_s)
      expect(flow).to be_readonly
    end

    it 'creates a flow version with the correct attributes' do
      flow = generated_flow
      flow_version = flow.versions.last

      expect(flow_version).to be_a(::Ai::Catalog::ItemVersion)
      expect(flow_version.schema_version).to eq(::Ai::Catalog::ItemVersion::AGENT_REFERENCED_FLOW_SCHEMA_VERSION)
      expect(flow_version.version).to eq(described_class::GENERATED_FLOW_VERSION)
    end

    it 'creates a flow definition with the correct structure' do
      flow = generated_flow
      flow_version = flow.versions.first
      definition = flow_version.definition

      expect(definition).to eq({
        "triggers" => [],
        "steps" => [
          {
            "agent_id" => agent.id,
            "current_version_id" => agent_version.id,
            "pinned_version_prefix" => agent_version.version
          }
        ]
      })
    end

    it 'sets pinned_version_prefix to the agent version string to ensure version pinning' do
      flow = generated_flow
      flow_version = flow.versions.first
      definition = flow_version.definition
      expect(definition["steps"].first["pinned_version_prefix"]).to eq(agent_version.version)
      expect(definition["steps"].first["pinned_version_prefix"]).not_to be_nil
    end
  end
end
