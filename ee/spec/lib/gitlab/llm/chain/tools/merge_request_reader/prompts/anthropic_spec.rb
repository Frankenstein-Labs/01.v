# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::MergeRequestReader::Prompts::Anthropic, feature_category: :duo_chat do
  describe '.prompt' do
    let(:options) { { input: 'test input', suggestions: 'test suggestions' } }

    describe '.prompt' do
      it 'returns prompt' do
        prompt = described_class.prompt(options)[:prompt]

        expect(prompt.length).to eq(3)

        expect(prompt[0][:role]).to eq(:system)
        expect(prompt[0][:content]).to eq(system_prompt)

        expect(prompt[1][:role]).to eq(:user)
        expect(prompt[1][:content]).to eq(options[:input])

        expect(prompt[2][:role]).to eq(:assistant)
        expect(prompt[2][:content]).to include(options[:suggestions], "\"ResourceIdentifierType\": \"")
      end

      it "calls with haiku model" do
        model = described_class.prompt(options)[:options][:model]

        expect(model).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_3_HAIKU)
      end
    end

    def system_prompt
      Gitlab::Llm::Chain::Tools::MergeRequestReader::Executor::SYSTEM_PROMPT[1]
    end
  end
end
