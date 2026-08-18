# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Concerns::ReaderTooling, feature_category: :duo_chat do
  let(:context) do
    ::Gitlab::Llm::Chain::GitlabContext.new(
      current_user: build(:user),
      container: double,
      resource: resource,
      ai_request: double
    )
  end

  let(:dummy_tool_class) do
    Class.new(::Gitlab::Llm::Chain::Tools::Tool) do
      include ::Gitlab::Llm::Chain::Concerns::ReaderTooling
    end
  end

  describe '#passed_content' do
    context 'with not serializable content' do
      let(:resource) { double }
      let(:response) { "I'm sorry, I can't generate a response. Please try again." }

      it 'returns error answer' do
        tool = dummy_tool_class.new(context: context, options: {})

        allow(tool).to receive(:provider_prompt_class)
                           .and_return(::Gitlab::Llm::Chain::Tools::IssueReader::Prompts::Anthropic)
        stub_const("::Gitlab::Llm::Chain::Tools::IssueReader::Prompts::Anthropic::MAX_CHARACTERS", 4)

        expect(Gitlab::Llm::Chain::Answer).to receive(:track_event)
        expect(tool.passed_content(nil).content).to include(response)
      end
    end
  end
end
