# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::Help::Executor, feature_category: :duo_chat do
  let_it_be(:user) { build_stubbed(:user) }
  let(:command_name) { '/help' }
  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }
  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: nil, resource: resource, ai_request: ai_request_double
    )
  end

  let(:resource) { create(:issue) }

  let(:expected_slash_commands) do
    {
      '/help' => {
        description: 'Explain the current vulnerability.'
      }
    }
  end

  let(:command) do
    instance_double(Gitlab::Llm::Chain::SlashCommand, :command, platform_origin: platform_origin)
  end

  let(:handler) do
    Gitlab::Llm::ResponseService.new(context, {})
  end

  let(:copy) { described_class::WEB_COPY }
  let(:platform_origin) { Gitlab::Llm::Chain::SlashCommand::WEB }

  subject(:tool) do
    described_class.new(
      context: context,
      options: {},
      command: command,
      stream_response_handler: handler
    )
  end

  shared_examples_for 'track internal event' do
    it_behaves_like 'internal event tracking' do
      let(:event) { 'request_ask_help' }
      let(:category) { described_class.to_s }
      let(:project) { resource.resource_parent }
      let(:namespace) { resource.resource_parent.group }

      subject(:track_event) { tool.execute }
    end
  end

  describe '#name' do
    it 'returns tool name' do
      expect(described_class::NAME).to eq('Help')
    end

    it 'returns resource name' do
      expect(described_class::RESOURCE_NAME).to be_nil
    end
  end

  describe '#execute' do
    context 'when request is from IDE' do
      let(:platform_origin) { Gitlab::Llm::Chain::SlashCommand::VS_CODE_EXTENSION }
      let(:copy) { described_class::IDE_COPY }

      it 'returns IDE copy' do
        expect(tool.execute.content).to eq(copy)
      end

      it_behaves_like 'track internal event'
    end

    context 'when request is from web' do
      let(:copy) { described_class::WEB_COPY }

      it 'returns web copy' do
        expect(tool.execute.content).to eq(copy)
      end

      it_behaves_like 'track internal event'
    end
  end
end
