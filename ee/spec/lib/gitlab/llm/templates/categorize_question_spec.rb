# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::CategorizeQuestion, feature_category: :duo_chat do
  let(:messages) { [] }
  let(:question) { 'what is the issue' }

  subject { described_class.new(messages, { question: question }) }

  describe '#to_prompt' do
    it 'includes question' do
      prompt = subject.to_prompt

      expect(prompt.dig(:messages, 0, :content)).to include(question)
    end

    it 'includes xmls' do
      prompt = subject.to_prompt

      expect(prompt.dig(:messages, 0, :content)).to include("Categories:\n<root>")
      expect(prompt.dig(:messages, 0, :content)).to include("Labels:\n<root>")
    end

    context 'when previous answer is absent' do
      it 'does not include previous answer' do
        prompt = subject.to_prompt

        expect(prompt.dig(:messages, 0, :content)).not_to include("Previous answer:\n<answer>")
      end
    end

    context 'when previous answer is present' do
      let(:messages) do
        [
          instance_double(Gitlab::Llm::ChatMessage, assistant?: true, content: '<LLM answer>'),
          instance_double(Gitlab::Llm::ChatMessage, assistant?: false, content: '<user input>')
        ]
      end

      it 'includes previous answer' do
        prompt = subject.to_prompt

        expect(prompt.dig(:messages, 0, :content)).to include("Previous answer:\n<answer>")
      end
    end
  end
end
