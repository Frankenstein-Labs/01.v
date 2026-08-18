# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::Agents, feature_category: :security_policy_management do
  describe '#agent_names' do
    context 'when agents is present' do
      it 'returns the agent names' do
        agents_data = { 'agent-name' => { namespaces: ['namespace1'] } }
        agents = described_class.new(agents_data)
        expect(agents.agent_names).to match_array(['agent-name'])
      end

      it 'handles agent names matching patternProperties schema' do
        agents_data = { 'agent-123' => { namespaces: ['default'] } }
        agents = described_class.new(agents_data)
        expect(agents.agent_names).to match_array(['agent-123'])
      end

      it 'handles agent names with hyphens' do
        agents_data = { 'my-agent-name' => { namespaces: ['default'] } }
        agents = described_class.new(agents_data)
        expect(agents.agent_names).to match_array(['my-agent-name'])
      end
    end

    context 'when agents is not present' do
      it 'returns an empty array' do
        agents = described_class.new({})
        expect(agents.agent_names).to be_empty
      end
    end

    context 'when agents is nil' do
      it 'returns an empty array' do
        agents = described_class.new(nil)
        expect(agents.agent_names).to be_empty
      end
    end
  end

  describe '#namespaces_for_agent' do
    context 'when agent exists with namespaces' do
      it 'returns the namespaces array' do
        agents_data = { 'agent-name' => { namespaces: %w[namespace1 namespace2] } }
        agents = described_class.new(agents_data)
        expect(agents.namespaces_for_agent('agent-name')).to match_array(%w[namespace1 namespace2])
      end

      it 'handles single namespace' do
        agents_data = { 'agent-name' => { namespaces: ['default'] } }
        agents = described_class.new(agents_data)
        expect(agents.namespaces_for_agent('agent-name')).to match_array(['default'])
      end
    end

    context 'when agent exists without namespaces' do
      it 'returns an empty array' do
        agents_data = { 'agent-name' => {} }
        agents = described_class.new(agents_data)
        expect(agents.namespaces_for_agent('agent-name')).to be_empty
      end
    end

    context 'when agent does not exist' do
      it 'returns an empty array' do
        agents_data = { 'other-agent' => { namespaces: ['default'] } }
        agents = described_class.new(agents_data)
        expect(agents.namespaces_for_agent('non-existent-agent')).to be_empty
      end
    end

    context 'when agents is empty' do
      it 'returns an empty array' do
        agents = described_class.new({})
        expect(agents.namespaces_for_agent('any-agent')).to be_empty
      end
    end
  end

  describe 'complete agents configuration' do
    it 'handles agents with single agent and multiple namespaces' do
      agents_data = {
        'my-agent' => {
          namespaces: %w[default production staging]
        }
      }
      agents = described_class.new(agents_data)

      expect(agents.agent_names).to match_array(['my-agent'])
      expect(agents.namespaces_for_agent('my-agent')).to match_array(%w[default production staging])
    end
  end
end
