# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      module SelfHosted
        class Vendored < CodeSuggestions::Prompts::Base
          include ::Ai::ModelSelection::Concerns::GitlabDefaultModelParams

          GATEWAY_PROMPT_VERSION = 1

          def request_params
            {
              model_provider: "gitlab",
              model_name: feature_setting&.offered_model_ref || '',
              prompt_version: GATEWAY_PROMPT_VERSION
            }
          end
        end
      end
    end
  end
end
