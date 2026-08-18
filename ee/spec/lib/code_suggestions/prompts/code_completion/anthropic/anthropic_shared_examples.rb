# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'anthropic code completion' do
  let_it_be(:current_user) { create(:user) }

  let(:content_above_cursor) do
    <<~CONTENT_ABOVE_CURSOR
      package main

      import "fmt"

      func main() {
    CONTENT_ABOVE_CURSOR
  end

  let(:file_name) { 'main.go' }
  let(:unsafe_params) do
    {
      'current_file' => {
        'file_name' => file_name,
        'content_above_cursor' => content_above_cursor
      },
      'telemetry' => [{ 'model_engine' => 'anthropic' }]
    }
  end

  let(:params) do
    {
      content_above_cursor: content_above_cursor,
      current_file: unsafe_params['current_file'].with_indifferent_access,
      stream: false,
      project_path: "gitlab-org/gitlab-shell"
    }
  end

  subject(:anthropic_completion) { described_class.new(params, current_user) }

  describe '#request_params' do
    it 'returns expected request params' do
      request_params = {
        model_provider: "anthropic",
        model_name: model_name,
        prompt_version: 3,
        prompt: [
          {
            role: :system,
            content: "You are a code completion tool that performs Fill-in-the-middle. Your task is to complete " \
              "the Go code between the given prefix and suffix inside the file 'main.go'.\nYour task is to provide " \
              "valid code without any additional explanations, comments, or feedback.\n\nImportant:\n- You MUST NOT " \
              "output any additional human text or explanation.\n- You MUST output code exclusively.\n- The " \
              "suggested code MUST work by simply concatenating to the provided code.\n- You MUST not include any " \
              "sort of markdown markup.\n- You MUST NOT repeat or modify any part of the prefix or suffix.\n- You " \
              "MUST only provide the missing code that fits between them.\n\nIf you are not able to complete code " \
              "based on the given instructions, return an empty result."
          },
          {
            role: :user,
            content: "<SUFFIX>\npackage main\n\nimport \"fmt\"\n\nfunc main() {\n\n</SUFFIX>\n<PREFIX>\n\n</PREFIX>"
          }
        ]
      }

      expect(anthropic_completion.request_params).to eq(request_params)
    end
  end
end
