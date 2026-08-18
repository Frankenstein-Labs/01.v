# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      module Anthropic
        class Base < CodeSuggestions::Prompts::Base
          include Gitlab::Utils::StrongMemoize
          include CodeSuggestions::Prompts::CodeCompletion::Anthropic::Concerns::Prompt

          MODEL_PROVIDER = 'anthropic'
          GATEWAY_PROMPT_VERSION = 3

          def request_params
            {
              model_provider: self.class::MODEL_PROVIDER,
              model_name: self.class::MODEL_NAME,
              prompt_version: self.class::GATEWAY_PROMPT_VERSION,
              prompt: prompt
            }
          end
        end
      end
    end
  end
end
