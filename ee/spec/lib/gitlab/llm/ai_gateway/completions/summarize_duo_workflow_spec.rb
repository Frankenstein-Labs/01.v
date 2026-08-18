# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::SummarizeDuoWorkflow,
  feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:prompt_message) do
    build(:ai_message, user: user, resource: project, request_id: 'uuid',
      ai_action: 'summarize_duo_workflow')
  end

  let(:inputs) { { logs: 'some log output' } }

  subject(:completion) { described_class.new(prompt_message, nil, inputs) }

  describe '#inputs' do
    it 'returns logs from options' do
      expect(completion.inputs).to eq(inputs)
    end
  end

  describe '#unit_primitive_name' do
    it 'uses duo_agent_platform as the unit primitive' do
      expect(completion.send(:unit_primitive_name)).to eq(:duo_agent_platform)
    end
  end
end
