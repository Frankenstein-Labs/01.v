# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::GenerateWorkflowTitleService, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
  let(:completion) { instance_double(Gitlab::Llm::AiGateway::Completions::GenerateDuoWorkflowTitle) }

  subject(:execute) { described_class.new(workflow: workflow).execute }

  before do
    allow(Gitlab::Llm::AiGateway::Completions::GenerateDuoWorkflowTitle).to receive(:new)
      .with(anything, nil, hash_including(context: anything, definition: anything))
      .and_return(completion)
  end

  context 'when the completion returns a title' do
    let(:ai_message) { instance_double(Gitlab::Llm::AiMessage, content: 'Fix the login bug') }

    before do
      allow(completion).to receive(:execute).and_return({ ai_message: ai_message })
    end

    it 'returns the title content' do
      expect(execute).to eq('Fix the login bug')
    end
  end

  context 'when the completion returns a title with surrounding whitespace' do
    let(:ai_message) { instance_double(Gitlab::Llm::AiMessage, content: "  Fix the login bug  \n") }

    before do
      allow(completion).to receive(:execute).and_return({ ai_message: ai_message })
    end

    it 'strips the content' do
      expect(execute).to eq('Fix the login bug')
    end
  end

  context 'when the completion returns an error hash as content' do
    let(:ai_message) { instance_double(Gitlab::Llm::AiMessage, content: { 'detail' => 'An unexpected error has occurred.' }) }

    before do
      allow(completion).to receive(:execute).and_return({ ai_message: ai_message })
    end

    it { is_expected.to be_nil }
  end

  context 'when the completion returns a nil ai_message' do
    before do
      allow(completion).to receive(:execute).and_return({ ai_message: nil })
    end

    it { is_expected.to be_nil }
  end

  context 'when the completion returns nil' do
    before do
      allow(completion).to receive(:execute).and_return(nil)
    end

    it { is_expected.to be_nil }
  end

  context 'when the completion raises an exception' do
    before do
      allow(completion).to receive(:execute).and_raise(StandardError, 'connection error')
    end

    it 'tracks the exception and returns nil' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception)
        .with(instance_of(StandardError), workflow_id: workflow.id)

      expect(execute).to be_nil
    end
  end

  context 'when workflow has no user' do
    before do
      allow(workflow).to receive(:user).and_return(nil)
    end

    it 'returns nil without calling the completion' do
      expect(Gitlab::Llm::AiGateway::Completions::GenerateDuoWorkflowTitle).not_to receive(:new)

      expect(execute).to be_nil
    end
  end

  context 'when workflow goal is blank' do
    before do
      allow(workflow).to receive(:goal).and_return('')
    end

    it 'returns nil without calling the completion' do
      expect(Gitlab::Llm::AiGateway::Completions::GenerateDuoWorkflowTitle).not_to receive(:new)

      expect(execute).to be_nil
    end
  end

  it 'passes context and definition to the completion' do
    ai_message = instance_double(Gitlab::Llm::AiMessage, content: 'title')
    allow(completion).to receive(:execute).and_return({ ai_message: ai_message })

    expect(Gitlab::Llm::AiGateway::Completions::GenerateDuoWorkflowTitle).to receive(:new)
      .with(anything, nil, { context: workflow.goal, definition: workflow.workflow_definition })
      .and_return(completion)

    execute
  end
end
