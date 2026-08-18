# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FoundationalChatAgent, feature_category: :workflow_catalog do
  describe 'included modules' do
    subject { described_class }

    it { is_expected.to include(ActiveRecord::FixedItemsModel::Model) }
    it { is_expected.to include(GlobalID::Identification) }
    it { is_expected.to include(Ai::FoundationalChatAgentsDefinitions) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:reference) }
    it { is_expected.to validate_presence_of(:description) }
  end

  describe 'duo_chat?' do
    context 'when duo chat' do
      it 'is true' do
        expect(described_class.all[0]).to be_duo_chat
      end
    end

    context 'when not duo chat' do
      it 'is false' do
        expect(described_class.all[1]).not_to be_duo_chat
      end
    end
  end

  describe '#item_type' do
    it 'returns the correct item type' do
      agent = described_class.find_by(reference: 'duo_planner')
      expect(agent.item_type).to eq('foundational_agent')
    end
  end

  describe '#count' do
    it 'returns the correct count of agents' do
      expect(described_class.count).to eq(described_class::ITEMS.size)
    end
  end

  describe '#workflow_definitions' do
    it 'is expected to return all workflow definitions' do
      expect(described_class.workflow_definitions.size).to be(described_class.count)
      expect(described_class.workflow_definitions[0]).to eq('chat')
    end
  end

  describe '#reference_with_version' do
    context 'when version is present' do
      it 'returns reference with version' do
        agent = described_class.new(reference: 'security_analyst_agent', version: 'v1')

        expect(agent.reference_with_version).to eq('security_analyst_agent/v1')
      end
    end

    context 'when version is blank' do
      it 'returns only reference' do
        agent = described_class.new(reference: 'chat', version: '')

        expect(agent.reference_with_version).to eq('chat')
      end
    end

    context 'when version is nil' do
      it 'returns only reference' do
        agent = described_class.new(reference: 'chat', version: nil)

        expect(agent.reference_with_version).to eq('chat')
      end
    end
  end

  describe '#workflow_definition' do
    it 'is the same as reference_with_version' do
      agent = described_class.new(reference: 'security_analyst_agent', version: 'v1')

      expect(agent.workflow_definition).to eq('security_analyst_agent/v1')
    end
  end

  describe '#foundational_workflow_definition?' do
    it 'returns true for chat' do
      expect(described_class.foundational_workflow_definition?('chat')).to be(true)
    end

    context 'if matching agent exists' do
      it 'returns true' do
        expect(described_class.foundational_workflow_definition?('duo_planner/v1')).to be(true)
      end
    end

    context 'if matching agent does not exist' do
      it 'returns false' do
        expect(described_class.foundational_workflow_definition?('some_agent')).to be(false)
      end
    end
  end

  describe '#reference_from_workflow_definition' do
    let(:workflow_definition) { 'security_analyst_agent/v1' }

    subject(:reference_from_workflow_definition) do
      described_class.reference_from_workflow_definition(workflow_definition)
    end

    it 'returns reference from workflow definition' do
      is_expected.to eq('security_analyst_agent')
    end

    context 'when version is blank' do
      let(:workflow_definition) { 'security_analyst_agent' }

      it 'returns reference from workflow definition' do
        is_expected.to eq('security_analyst_agent')
      end
    end
  end

  describe '#to_global_id' do
    context 'when version is present' do
      it 'returns reference with version' do
        agent = described_class.new(reference: 'security_analyst_agent', version: 'v1')

        expect(agent.to_global_id).to eq('security_analyst_agent-v1')
      end
    end

    context 'when version is blank' do
      it 'returns reference with blank version' do
        agent = described_class.new(reference: 'chat', version: '')

        expect(agent.to_global_id).to eq('chat')
      end
    end

    context 'when version is nil' do
      it 'returns reference with blank version' do
        agent = described_class.new(reference: 'chat', version: nil)

        expect(agent.to_global_id).to eq('chat')
      end
    end
  end

  describe '#only_duo_chat' do
    it 'returns only duo chat agents' do
      only_chat = described_class.only_duo_chat_agent
      expect(only_chat.size).to eq(described_class::CHAT_REFERENCES.size)
      expect(only_chat.map(&:name)).to all(eq('GitLab Duo'))
    end
  end

  describe '#except_duo_chat_agent' do
    it 'returns all but duo chat agents' do
      expect_duo_chat = described_class.except_duo_chat_agent
      expect(expect_duo_chat.size).to eq(described_class::ITEMS.size - described_class::CHAT_REFERENCES.size)
      expect(expect_duo_chat.map(&:reference)).not_to include(*described_class::CHAT_REFERENCES)
    end
  end

  describe '.for_catalog_item' do
    context 'when an agent with matching global_catalog_id exists' do
      it 'returns the agent' do
        agent = described_class.for_catalog_item(356)

        expect(agent.reference).to eq('security_analyst_agent')
      end
    end

    context 'when no agent has the given global_catalog_id' do
      it 'returns nil' do
        expect(described_class.for_catalog_item(999999)).to be_nil
      end
    end

    context 'when nil is passed' do
      it 'returns nil' do
        expect(described_class.for_catalog_item(nil)).to be_nil
      end
    end
  end

  describe '.find_by_reference' do
    context 'when the reference matches an agent' do
      it 'returns the agent' do
        agent = described_class.find_by_reference('duo_planner')

        expect(agent).to be_a(described_class)
        expect(agent.reference).to eq('duo_planner')
      end
    end

    context 'when the reference does not match any agent' do
      it 'returns nil' do
        expect(described_class.find_by_reference('nonexistent')).to be_nil
      end
    end
  end

  describe '#system_prompt' do
    context 'when the prompt file exists' do
      it 'returns the file contents' do
        agent = described_class.find_by(reference: 'duo_planner')

        expect(agent.system_prompt).to be_a(String)
        expect(agent.system_prompt).not_to be_empty
      end
    end

    context 'when the prompt file does not exist' do
      it 'returns nil' do
        agent = described_class.find_by(reference: 'chat')

        expect(agent.system_prompt).to be_nil
      end
    end
  end

  describe '#built_in_tools' do
    it 'returns matching BuiltInTool records' do
      agent = described_class.find_by(reference: 'duo_planner')

      tools = agent.built_in_tools

      expect(tools).to be_an(Array)
      expect(tools).not_to be_empty
      expect(tools).to all(be_a(::Ai::Catalog::BuiltInTool))
    end
  end

  describe '#any_agents_with_reference?' do
    it 'is true if reference for foundational agent' do
      expect(described_class.any_agents_with_reference?('duo_planner')).to be true
    end

    it 'is false if reference not for foundational agent' do
      expect(described_class.any_agents_with_reference?('invalid_agent_1')).to be false
    end
  end

  describe '#with_workflow_definition' do
    context 'when agent with workflow definition exists' do
      it 'returns the agent for chat without version' do
        agent = described_class.with_workflow_definition('chat')

        expect(agent).not_to be_nil
        expect(agent.reference).to eq('chat')
        expect(agent.name).to eq('GitLab Duo')
      end

      it 'returns the agent for workflow definition with version' do
        agent = described_class.with_workflow_definition('duo_planner/v1')

        expect(agent).not_to be_nil
        expect(agent.reference).to eq('duo_planner')
        expect(agent.version).to eq('v1')
        expect(agent.name).to eq('Planner')
      end

      it 'returns the agent for analytics agent' do
        agent = described_class.with_workflow_definition('analytics_agent/v1')

        expect(agent).not_to be_nil
        expect(agent.reference).to eq('analytics_agent')
        expect(agent.version).to eq('v1')
        expect(agent.name).to eq('Data Analyst')
      end
    end

    context 'when agent with workflow definition does not exist' do
      it 'returns nil' do
        agent = described_class.with_workflow_definition('nonexistent_agent/v1')

        expect(agent).to be_nil
      end
    end
  end

  describe '.to_sql' do
    let(:column_overrides) { { organization_id: 2 } }
    let(:columns_with_types) do
      { id: :bigint, name: :text, description: :text, reference: :text, foobar: :text, organization_id: :bigint }
    end

    subject(:to_sql) { described_class.to_sql(columns_with_types:, column_overrides:) }

    it 'returns rows for each item with the correct attributes' do
      rows = ApplicationRecord.connection.execute(to_sql)

      expect(rows.count).to eq(described_class.count)

      planner_item = described_class.find_by(reference: 'duo_planner')
      planner_row = rows.find { |row| row['reference'] == 'duo_planner' }

      expect(planner_row['id']).to eq(planner_item.id)
      expect(planner_row['name']).to eq(planner_item.name)
      expect(planner_row['description']).to eq(planner_item.description)

      expect(planner_row['organization_id']).to eq(2)
      expect(planner_row).to have_key('foobar')
      expect(planner_row['foobar']).to be_nil
    end

    it 'casts the columns to the correct types and quotes the column values and names' do
      expect(to_sql).to include('1::bigint')
      expect(to_sql).to include("'Security Analyst'::text")
      expect(to_sql).to include('"foobar"')
    end
  end
end
