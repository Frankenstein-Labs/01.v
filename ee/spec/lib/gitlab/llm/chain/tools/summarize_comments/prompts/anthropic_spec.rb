# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::SummarizeComments::Prompts::Anthropic, feature_category: :duo_chat do
  let(:variables) do
    {
      notes_content: '<comment>foo</comment>'
    }
  end

  describe '.prompt' do
    it "returns prompt" do
      prompt = described_class.prompt(variables)[:prompt]
      expect(prompt.length).to eq(3)

      expect(prompt[0][:role]).to eq(:system)
      expect(prompt[0][:content]).to eq(system_prompt_content)

      expect(prompt[1][:role]).to eq(:user)
      expect(prompt[1][:content]).to eq(format(
        Gitlab::Llm::Chain::Tools::SummarizeComments::Executor::USER_PROMPT[1], variables).to_s)

      expect(prompt[2][:role]).to eq(:assistant)
      expect(prompt[2][:content]).to be_empty
    end

    it "calls with claude 3 haiku model" do
      model = described_class.prompt(variables)[:options][:model]

      expect(model).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_3_5_SONNET)
    end
  end

  def system_prompt_content
    Gitlab::Llm::Chain::Tools::SummarizeComments::Executor::SYSTEM_PROMPT[1]
  end
end
