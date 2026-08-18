# frozen_string_literal: true

require 'spec_helper'
require_relative 'ai_gateway_shared_examples'

RSpec.describe CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages, feature_category: :code_suggestions do
  let(:prompt_version) { 3 }

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
  end

  it_behaves_like 'code generation AI Gateway request params' do
    def expected_request_params
      {
        prompt_components: [
          {
            type: 'code_editor_generation',
            payload: {
              file_name: expected_file_name,
              content_above_cursor: expected_content_above_cursor,
              content_below_cursor: expected_content_below_cursor,
              language_identifier: expected_language_identifier,
              prompt_id: expected_prompt_id,
              prompt_version: expected_prompt_version,
              stream: expected_stream,
              prompt_enhancer: {
                examples_array: expected_examples_array,
                trimmed_content_above_cursor: expected_trimmed_content_above_cursor,
                trimmed_content_below_cursor: expected_trimmed_content_below_cursor,
                related_files: expected_related_files,
                related_snippets: expected_related_snippets,
                libraries: expected_libraries,
                user_instruction: expected_user_instruction
              }
            }
          }
        ]
      }
    end
  end
end
