# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::GenerateDuoWorkflowTitle,
  feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:prompt_message) do
    build(:ai_message, user: user, resource: project, request_id: 'uuid',
      ai_action: 'generate_duo_workflow_title')
  end

  let(:inputs) { { context: 'Fix the login bug', definition: 'developer/v1' } }

  subject(:completion) { described_class.new(prompt_message, nil, inputs) }

  describe '#inputs' do
    it 'returns context and definition from options' do
      expect(completion.inputs).to eq(inputs)
    end

    it 'does not include other keys' do
      completion_with_extra = described_class.new(prompt_message, nil, inputs.merge(goal: 'old key'))

      expect(completion_with_extra.inputs).not_to have_key(:goal)
    end
  end

  describe '#prompt_name' do
    it 'uses generate_session_title as the prompt name' do
      expect(completion.send(:prompt_name)).to eq('generate_session_title')
    end
  end

  describe '#unit_primitive_name' do
    it 'uses duo_agent_platform as the unit primitive' do
      expect(completion.send(:unit_primitive_name)).to eq(:duo_agent_platform)
    end
  end

  describe '#root_namespace' do
    it 'returns the root ancestor of the resource' do
      expect(completion.send(:root_namespace)).to eq(project.root_ancestor)
    end

    context 'when there is no resource' do
      let(:prompt_message) do
        build(:ai_message, user: user, resource: nil, request_id: 'uuid',
          ai_action: 'generate_duo_workflow_title')
      end

      it 'returns nil' do
        expect(completion.send(:root_namespace)).to be_nil
      end
    end
  end
end
