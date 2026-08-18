# frozen_string_literal: true

RSpec.shared_context 'with mocked Foundational Chat Agents' do
  let(:invalid_agent_reference) { 'invalid_agent_reference' }
  let(:foundational_duo_chat_agent) do
    {
      id: 1,
      reference: 'chat',
      version: '',
      name: 'GitLab Duo',
      description: "duo_chat"
    }
  end

  let(:foundational_chat_agent_1) do
    {
      id: 2,
      reference: 'agent_1',
      version: 'experimental',
      name: 'Agent 1',
      description: 'First agent'
    }
  end

  let(:foundational_chat_agent_2) do
    {
      id: 3,
      reference: 'agent_2',
      version: 'experimental',
      name: 'Agent 2',
      description: 'Second agent'
    }
  end

  let(:foundational_chat_agent_1_ref) do
    foundational_chat_agent_1[:reference]
  end

  let(:foundational_chat_agent_1_workflow_definition) do
    "#{foundational_chat_agent_1[:reference]}/#{foundational_chat_agent_1[:version]}"
  end

  let(:foundational_chat_agent_2_ref) do
    foundational_chat_agent_2[:reference]
  end

  let(:foundational_hidden_chat_agent) do
    {
      id: 99,
      reference: 'hidden_agent',
      version: 'v1',
      name: 'Hidden Agent',
      description: 'A hidden agent',
      selectable_in_chat: false
    }
  end

  let(:mocked_foundational_chat_agents) do
    [foundational_duo_chat_agent, foundational_chat_agent_1, foundational_chat_agent_2]
  end

  before do
    allow(::Ai::FoundationalChatAgent).to receive(:storage).and_return(
      mocked_foundational_chat_agents.map { |v| ::Ai::FoundationalChatAgent.new(v) }
    )
  end
end
