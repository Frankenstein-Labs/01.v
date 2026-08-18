# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::WriteTests::Prompts::Anthropic, feature_category: :duo_chat do
  let(:user) { create(:user) }

  describe '.prompt' do
    it 'returns prompt', :aggregate_failures do
      result = described_class.prompt(
        input: 'question',
        language_info: 'language',
        selected_text: 'selected text',
        file_content: 'file content'
      )
      prompt = result[:prompt]

      expected_system_prompt = "You are a software developer.\nYou can write new tests.\nlanguage\n"

      expected_user_prompt = <<~PROMPT.chomp
          file content
          In the file user selected this code:
          <selected_code>
            selected text
          </selected_code>

          question
          Any code blocks in response should be formatted in markdown.
      PROMPT

      expected_prompt = [
        {
          role: :system, content: expected_system_prompt
        },
        {
          role: :user, content: expected_user_prompt
        }
      ]
      expect(prompt).to eq(expected_prompt)
    end
  end
end
