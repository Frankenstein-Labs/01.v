# frozen_string_literal: true

module CodeSuggestions
  module Tasks
    class CodeCompletion < Base
      extend ::Gitlab::Utils::Override
      include Gitlab::Utils::StrongMemoize

      delegate :saas_primary_model_class, :remap_model, to: :model_details

      override :endpoint
      def endpoint
        return "#{base_url}/v4/code/suggestions" if use_v4_endpoint?

        "#{base_url}/v2/code/#{endpoint_name}"
      end

      private

      override :prompt_request_params
      def prompt_request_params
        # On v4 the AI Gateway resolves the model, so no client-side remapping is needed.
        return prompt.request_params if use_v4_endpoint?

        remap_model(prompt.request_params)
      end

      def use_v4_endpoint?
        Feature.enabled?(:code_completion_v4_endpoint, current_user)
      end
      strong_memoize_attr :use_v4_endpoint?

      override :endpoint_name
      def endpoint_name
        'completions'
      end

      override :model_details
      def model_details
        @model_details ||= CodeSuggestions::ModelDetails::CodeCompletion.new(
          current_user: current_user,
          root_namespace: params[:project]&.root_namespace
        )
      end

      def prompt
        return code_editor_completion_prompt if use_v4_endpoint?

        if ::Ai::AmazonQ.connected?
          amazon_q_prompt
        elsif self_hosted?
          self_hosted_prompt
        elsif vendored?
          self_hosted_vendored_prompt
        elsif use_model_switching?
          model_switching_ai_gateway_prompt
        else
          saas_prompt
        end
      end
      strong_memoize_attr :prompt

      def self_hosted_prompt
        CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeCompletionMessage.new(
          params,
          current_user,
          feature_setting
        )
      end

      def saas_prompt
        if Feature.enabled?(:incident_fail_over_completion_provider, current_user)
          CodeSuggestions::Prompts::CodeCompletion::Anthropic::ClaudeSonnet.new(params, current_user)
        else
          saas_primary_model_class.new(params, current_user)
        end
      end

      def model_switching_ai_gateway_prompt
        CodeSuggestions::Prompts::CodeCompletion::ModelSwitching::AiGateway.new(
          params,
          current_user,
          feature_setting
        )
      end

      def self_hosted_vendored_prompt
        return saas_prompt if feature_setting.set_to_gitlab_default?

        CodeSuggestions::Prompts::CodeCompletion::SelfHosted::Vendored.new(
          params,
          current_user,
          feature_setting
        )
      end

      def amazon_q_prompt
        CodeSuggestions::Prompts::CodeCompletion::AmazonQ.new(params, current_user)
      end

      def code_editor_completion_prompt
        CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeEditorCompletion.new(
          params,
          current_user,
          feature_setting
        )
      end

      def use_model_switching?
        namespace_feature_setting? && !feature_setting.set_to_gitlab_default?
      end
    end
  end
end
