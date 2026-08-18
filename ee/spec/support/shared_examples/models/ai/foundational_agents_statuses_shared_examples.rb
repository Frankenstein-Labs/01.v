# frozen_string_literal: true

RSpec.shared_examples 'settings with foundational agents statuses' do
  include_context 'with mocked Foundational Chat Agents'

  it { is_expected.to include_module(Ai::FoundationalAgentsStatusable) }
  it { is_expected.to respond_to(:foundational_agents_default_enabled) }

  describe 'associations' do
    it { expect(instance).to have_many(:foundational_agents_status_records) }
  end

  let(:valid_enabled_status) { [{ reference: foundational_chat_agent_1_ref, enabled: true }] }

  before do
    instance.errors.clear
  end

  describe '#foundational_agents_statuses=' do
    it 'does not update when value is nil' do
      instance.foundational_agents_statuses = valid_enabled_status

      instance.foundational_agents_statuses = nil

      expect(instance.reload.foundational_agents_status_records.size).to eq 1
      expect(instance.foundational_agents_status_records[0].reference).to eq foundational_chat_agent_1_ref
      expect(instance.foundational_agents_status_records[0].enabled).to be true
    end

    it 'updates when value is empty' do
      instance.foundational_agents_statuses = valid_enabled_status

      instance.foundational_agents_statuses = []

      expect(instance.reload.foundational_agents_status_records).to eq([])
    end

    it 'rollbacks if an error happens' do
      instance.update!(foundational_agents_status_records: [])

      instance.foundational_agents_statuses = [*valid_enabled_status, { enabled: true }]

      expect(instance.errors.messages[:foundational_agents_statuses]).not_to be_empty

      expect(instance.reload.foundational_agents_status_records).to be_empty
    end

    it 'raises an error for invalid reference' do
      statuses = [
        { reference: 'invalid_agent', enabled: true }
      ]

      instance.foundational_agents_statuses = statuses

      expect(instance.errors.messages[:foundational_agents_statuses])
        .to include("Reference is not a valid foundational agent reference")
    end

    it 'replaces existing records' do
      instance.foundational_agents_statuses = valid_enabled_status
      instance.foundational_agents_statuses = [{ reference: foundational_chat_agent_2_ref, enabled: false }]

      records = instance.reload.foundational_agents_status_records
      expect(records.size).to eq 1
      expect(records[0].reference).to eq foundational_chat_agent_2_ref
      expect(records[0].enabled).to be false
    end
  end

  describe '#foundational_agents_statuses' do
    before do
      instance.foundational_agents_statuses = valid_enabled_status
    end

    it 'includes agent metadata from FoundationalChatAgent definitions' do
      statuses = instance.reload.foundational_agents_statuses

      agent_1_status = statuses.find { |a| a[:reference] == foundational_chat_agent_1_ref }

      expect(agent_1_status[:name]).to eq(foundational_chat_agent_1[:name])
      expect(agent_1_status[:description]).to eq(foundational_chat_agent_1[:description])
      expect(agent_1_status[:enabled]).to be true

      agent_2_status = statuses.find { |a| a[:reference] == foundational_chat_agent_2_ref }

      expect(agent_2_status[:name]).to eq(foundational_chat_agent_2[:name])
      expect(agent_2_status[:description]).to eq(foundational_chat_agent_2[:description])
      expect(agent_2_status[:enabled]).to be_nil
    end
  end

  describe '#enabled_foundational_agents' do
    subject(:enabled_agents_references) { instance.enabled_foundational_agents.map(&:reference) }

    let(:foundational_agents_statuses) { [] }
    let(:default_enabled) { true }

    before do
      allow(instance).to receive(:foundational_agents_default_enabled).and_return(default_enabled)
      instance.foundational_agents_statuses = foundational_agents_statuses
    end

    context 'when no status records exist' do
      context 'when default_enabled is true' do
        it 'returns all agents' do
          is_expected.to contain_exactly('chat', foundational_chat_agent_1_ref, foundational_chat_agent_2_ref)
        end
      end

      context 'when default_enabled is false' do
        let(:default_enabled) { false }

        it 'returns empty array' do
          is_expected.to contain_exactly('chat')
        end
      end
    end

    context 'when status records exist' do
      let(:foundational_agents_statuses) do
        [
          { reference: foundational_chat_agent_1_ref, enabled: true },
          { reference: foundational_chat_agent_2_ref, enabled: false }
        ]
      end

      context 'when default_enabled is false' do
        let(:default_enabled) { false }

        it 'returns only enabled agents regardless of default_enabled' do
          is_expected.to contain_exactly('chat', foundational_chat_agent_1_ref)
        end
      end

      context 'when default_enabled is true' do
        let(:default_enabled) { true }

        it 'respects explicit enabled status over default_enabled' do
          is_expected.to contain_exactly('chat', foundational_chat_agent_1_ref)
        end
      end
    end

    context 'when some agents have status records and others do not' do
      let(:foundational_agents_statuses) do
        [{ reference: foundational_chat_agent_1_ref, enabled: false }]
      end

      context 'when default_enabled is true' do
        let(:default_enabled) { true }

        it 'uses default_enabled for agents without status records' do
          is_expected.to contain_exactly('chat', foundational_chat_agent_2_ref)
        end
      end

      context 'when default_enabled is false' do
        let(:default_enabled) { false }

        it 'respects explicit status for agents with records' do
          is_expected.to contain_exactly('chat')
        end
      end
    end

    context 'when all agents are explicitly disabled' do
      let(:default_enabled) { true }
      let(:foundational_agents_statuses) do
        [
          { reference: foundational_chat_agent_1_ref, enabled: false },
          { reference: foundational_chat_agent_2_ref, enabled: false }
        ]
      end

      it 'returns empty array even when default_enabled is true' do
        is_expected.to contain_exactly('chat')
      end
    end

    context 'when all agents are explicitly enabled' do
      let(:default_enabled) { false }
      let(:foundational_agents_statuses) do
        [
          { reference: foundational_chat_agent_1_ref, enabled: true },
          { reference: foundational_chat_agent_2_ref, enabled: true }
        ]
      end

      it 'returns all agents even when default_enabled is false' do
        is_expected.to contain_exactly('chat', foundational_chat_agent_1_ref, foundational_chat_agent_2_ref)
      end
    end
  end

  describe '#foundational_agent_enabled?' do
    using RSpec::Parameterized::TableSyntax

    subject(:agent_enabled) { instance.foundational_agent_enabled?(agent_reference) }

    let(:agent_reference) { foundational_chat_agent_1_ref }

    before do
      allow(instance).to receive(:foundational_agents_default_enabled).and_return(default_enabled)

      instance.foundational_agents_statuses = if status_exists
                                                [{ reference: foundational_chat_agent_1_ref, enabled: status_enabled }]
                                              else
                                                []
                                              end
    end

    where(:status_exists, :status_enabled, :default_enabled, :expected_result) do
      false  | nil    | true  | true
      false  |  nil   | false |  false
      true   |  true  | false |  true
      true   |  false | true  |  false
    end

    with_them do
      it { is_expected.to be expected_result }
    end
  end
end
