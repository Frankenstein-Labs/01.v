# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Requests
        class AiGateway < Base
          extend ::Gitlab::Utils::Override

          include ::Gitlab::Utils::StrongMemoize
          include ::Gitlab::Llm::Concerns::AvailableModels
          include ::Gitlab::Llm::Concerns::AllowedParams
          include ::Gitlab::Llm::Concerns::EventTracking

          attr_reader :ai_client, :tracking_context, :root_namespace

          BASE_PROMPTS_CHAT_ENDPOINT = '/v1/prompts/chat'
          BASE_PROMPTS_CHAT_V2_ENDPOINT = '/v2/prompts/chat'
          DEFAULT_TYPE = 'prompt'
          DEFAULT_SOURCE = 'GitLab EE'
          TEMPERATURE = 0.1
          STOP_WORDS = ["\n\nHuman", "Observation:"].freeze
          DEFAULT_MAX_TOKENS = 4096

          def initialize(user, unit_primitive_name:, tracking_context: {}, root_namespace: nil)
            @user = user
            @tracking_context = tracking_context
            @root_namespace = root_namespace
            @ai_client = ::Gitlab::Llm::AiGateway::Client.new(
              user,
              unit_primitive_name: unit_primitive_name,
              tracking_context: tracking_context,
              governing_namespace_id: root_namespace&.id)
          end

          def request(prompt, unit_primitive: nil)
            options = prompt.fetch(:options, {})
            return unless model_provider_valid?(options)

            response = ai_client.stream(
              url: endpoint(unit_primitive),
              body: body(options, unit_primitive: unit_primitive)
            ) do |data|
              yield data if block_given?
            end

            log_conditional_info(user,
              message: "Made request to AI Client",
              event_name: 'response_received',
              ai_component: 'duo_chat',
              prompt: prompt[:prompt],
              response_from_llm: response,
              unit_primitive: unit_primitive)

            track_prompt_size(token_size(prompt[:prompt]), provider(options))
            track_response_size(token_size(response), provider(options))

            response
          end

          private

          attr_reader :user

          def default_options
            {
              temperature: TEMPERATURE,
              stop_sequences: STOP_WORDS,
              max_tokens_to_sample: DEFAULT_MAX_TOKENS
            }
          end

          def model(options)
            return options[:model] if options[:model].present?

            CLAUDE_3_5_SONNET
          end

          def provider(options)
            AVAILABLE_MODELS.find do |_, models|
              models.include?(model(options))
            end&.first
          end

          def model_provider_valid?(options)
            provider(options)
          end

          def endpoint(unit_primitive)
            raise ArgumentError, "unit_primitive cannot be nil" if unit_primitive.nil?

            base_url = feature_setting(unit_primitive)&.base_url || ::Gitlab::AiGateway.url
            prompts_endpoint = if Feature.enabled?(:ai_prompts_v2, user)
                                 BASE_PROMPTS_CHAT_V2_ENDPOINT
                               else
                                 BASE_PROMPTS_CHAT_ENDPOINT
                               end

            "#{base_url}#{prompts_endpoint}/#{unit_primitive}"
          end

          def body(options, unit_primitive: nil)
            request_body_agent(inputs: options[:inputs], unit_primitive: unit_primitive,
              prompt_version: options[:prompt_version])
          end

          def request_body(prompt:, options: {}, unit_primitive: nil)
            {
              prompt_components: [{
                type: DEFAULT_TYPE,
                metadata: {
                  source: DEFAULT_SOURCE,
                  version: Gitlab.version_info.to_s
                },
                payload: {
                  content: prompt
                }.merge(payload_params(options)).merge(model_params(options, unit_primitive))
              }],
              stream: true
            }
          end

          def request_body_agent(inputs:, unit_primitive: nil, prompt_version: nil)
            params = {
              stream: true,
              inputs: inputs
            }

            feature_setting = feature_setting(unit_primitive)

            model_metadata = model_metadata(feature_setting)
            params[:model_metadata] = model_metadata if model_metadata.present?

            model_family = model_metadata && model_metadata[:name]
            default_version = ::Gitlab::Llm::PromptVersions.version_for_prompt("chat/#{unit_primitive}", model_family)

            is_self_hosted = feature_setting&.self_hosted? || false
            params[:prompt_version] = if is_self_hosted || ::Ai::AmazonQ.connected?
                                        default_version
                                      else
                                        prompt_version || default_version
                                      end

            params
          end

          def model_metadata(feature_setting)
            ::Gitlab::Llm::AiGateway::ModelMetadata.new(feature_setting: feature_setting).to_params
          end

          def model_params(options, unit_primitive = nil)
            unit_primitive ||= options[:unit_primitive]
            feature_setting = feature_setting(unit_primitive)

            model_info = feature_setting&.model_request_params

            return model_info if model_info

            # Default model parameters
            {
              provider: provider(options),
              model: model(options)
            }
          end

          def feature_setting(unit_primitive)
            strong_memoize_with(:feature_setting, unit_primitive) do
              feature_name = ::Ai::FeatureSetting.feature_name_for_unit_primitive(unit_primitive) || 'duo_chat'

              feature_setting = get_feature_setting_for(feature_name)

              if feature_setting.nil? && feature_name&.to_sym != :duo_chat
                feature_setting = get_feature_setting_for(:duo_chat)
              end

              feature_setting
            end
          end

          def payload_params(options)
            allowed_params = ALLOWED_PARAMS.fetch(provider(options))
            params = options.slice(*allowed_params)

            { params: params }.compact_blank
          end

          def token_size(content)
            # Anthropic's APIs don't send used tokens as part of the response, so
            # instead we estimate the number of tokens based on typical token size
            # one token is roughly 4 chars.
            content.to_s.size / 4
          end

          override :tracking_class_name
          def tracking_class_name(provider)
            TRACKING_CLASS_NAMES.fetch(provider)
          end

          def unavailable_resources
            %w[Pipelines Vulnerabilities]
          end

          def get_feature_setting_for(feature_name)
            ::Ai::FeatureSettingSelectionService
                                .new(user, feature_name, root_namespace)
                                .execute.payload
          end
        end
      end
    end
  end
end
