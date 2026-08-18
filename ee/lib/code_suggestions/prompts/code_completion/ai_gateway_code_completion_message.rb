# frozen_string_literal: true

module CodeSuggestions
  module Prompts
    module CodeCompletion
      class AiGatewayCodeCompletionMessage < CodeSuggestions::Prompts::Base
        GATEWAY_PROMPT_VERSION = 2
        MODEL_PROVIDER = 'litellm'

        def params
          self_hosted_model = feature_setting&.self_hosted_model

          return super unless self_hosted_model

          super.merge({
            model_name: self_hosted_model.model,
            model_endpoint: self_hosted_model.endpoint,
            model_api_key: self_hosted_model.api_token,
            model_identifier: self_hosted_model.identifier
          })
        end

        def request_params
          {
            model_provider: self.class::MODEL_PROVIDER,
            prompt_version: self.class::GATEWAY_PROMPT_VERSION,
            prompt: prompt,
            model_endpoint: params[:model_endpoint]
          }.tap do |opts|
            opts[:model_name] = params[:model_name] if params[:model_name].present?
            opts[:model_api_key] = params[:model_api_key] if params[:model_api_key].present?
            opts[:model_identifier] = params[:model_identifier] if params[:model_identifier].present?
          end
        end

        def prompt
          nil
        end

        private

        def pick_content_above_cursor
          content_above_cursor.last(500)
        end

        def pick_content_below_cursor
          content_below_cursor.first(500)
        end
      end
    end
  end
end
