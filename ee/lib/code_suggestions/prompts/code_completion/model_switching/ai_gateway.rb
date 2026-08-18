# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      module ModelSwitching
        class AiGateway < CodeSuggestions::Prompts::Base
          include CodeSuggestions::Prompts::CodeCompletion::Anthropic::Concerns::Prompt

          GATEWAY_PROMPT_VERSION = 3
          MODEL_PROVIDER = 'gitlab'
          GITLAB_PROVIDED_ANTHROPIC_MODELS_FOR_CODE_COMPLETION = %w[
            claude_sonnet_3_7_20250219
            claude_3_5_sonnet_20240620
          ].freeze

          def request_params
            model_name = determine_model_name

            {
              model_provider: self.class::MODEL_PROVIDER,
              model_name: model_name.to_s,
              prompt_version: self.class::GATEWAY_PROMPT_VERSION,
              prompt: find_prompt(model_name)
            }
          end

          private

          def find_prompt(model_name)
            # We still need to pass the prompt due to legacy reasons, but only for Anthropic models.
            # See https://gitlab.com/gitlab-org/gitlab/-/issues/548241#note_2553250550 for details.
            return unless GITLAB_PROVIDED_ANTHROPIC_MODELS_FOR_CODE_COMPLETION.include?(model_name.to_s)

            prompt
          end

          def determine_model_name
            feature_setting.offered_model_ref
          end
        end
      end
    end
  end
end
