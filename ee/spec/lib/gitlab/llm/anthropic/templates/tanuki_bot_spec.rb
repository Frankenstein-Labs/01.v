# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::Templates::TanukiBot, feature_category: :duo_chat do
  let(:question) { 'How to do something?' }
  let(:documents) { [{ id: 1, content: 'foo' }, { id: 2, content: 'bar' }] }

  subject(:final_prompt) { described_class.final_prompt(question: question, documents: documents) }

  describe '#final_prompt' do
    it "returns prompt" do
      prompt = final_prompt[:prompt]

      expect(prompt.length).to eq(2)
      expect(prompt[0][:role]).to eq(:user)
      expect(prompt[0][:content]).to include(question)
      expect(prompt[1][:role]).to eq(:assistant)
      expect(prompt[1][:content]).to include('FINAL ANSWER:')

      expect(final_prompt.dig(:options, :model)).to eq(::Gitlab::Llm::Anthropic::Client::CLAUDE_3_7_SONNET)

      expect(final_prompt.dig(:options, :inputs, :question)).to eq(question)
      expect(final_prompt.dig(:options, :inputs, :content_id)).to eq(described_class::CONTENT_ID_FIELD)
      expect(final_prompt.dig(:options, :inputs, :documents)).to eq(documents)
    end
  end
end
