# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::SummarizeWorkflowService, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
  let(:completion) { instance_double(Gitlab::Llm::AiGateway::Completions::SummarizeDuoWorkflow) }

  subject(:execute) { described_class.new(workflow: workflow).execute }

  before do
    allow_next_instance_of(described_class) do |instance|
      allow(instance).to receive(:fetch_logs).and_return('some log output')
    end
    allow(Gitlab::Llm::AiGateway::Completions::SummarizeDuoWorkflow).to receive(:new)
      .with(anything, nil, hash_including(logs: anything))
      .and_return(completion)
  end

  context 'when the completion returns a summary' do
    let(:ai_message) { instance_double(Gitlab::Llm::AiMessage, content: 'Workflow completed successfully.') }

    before do
      allow(completion).to receive(:execute).and_return({ ai_message: ai_message })
    end

    it 'returns the summary content' do
      expect(execute).to eq('Workflow completed successfully.')
    end
  end

  context 'when the completion returns a summary with surrounding whitespace' do
    let(:ai_message) { instance_double(Gitlab::Llm::AiMessage, content: "  summary text  \n") }

    before do
      allow(completion).to receive(:execute).and_return({ ai_message: ai_message })
    end

    it 'strips the content' do
      expect(execute).to eq('summary text')
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
      expect(Gitlab::Llm::AiGateway::Completions::SummarizeDuoWorkflow).not_to receive(:new)

      expect(execute).to be_nil
    end
  end

  context 'when logs exceed MAX_LOG_LENGTH_IN_CHARS' do
    let(:long_logs) { 'a' * (described_class::MAX_LOG_LENGTH_IN_CHARS + 1000) }

    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:fetch_logs).and_call_original
      end
      allow(workflow).to receive_message_chain(:last_workload, :pipeline, :builds, :failed, :last, :trace, :raw)
        .and_return(long_logs)
      allow(completion).to receive(:execute).and_return(nil)
    end

    it 'passes only the last MAX_LOG_LENGTH_IN_CHARS characters to the completion' do
      expect(Gitlab::Llm::AiGateway::Completions::SummarizeDuoWorkflow).to receive(:new)
        .with(anything, nil, { logs: long_logs.last(described_class::MAX_LOG_LENGTH_IN_CHARS) })
        .and_return(completion)

      execute
    end
  end

  context 'when the workflow has no workload' do
    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:fetch_logs).and_call_original
      end
      allow(workflow).to receive(:last_workload).and_return(nil)
    end

    it 'returns nil without calling the completion' do
      expect(Gitlab::Llm::AiGateway::Completions::SummarizeDuoWorkflow).not_to receive(:new)

      expect(execute).to be_nil
    end
  end
end
