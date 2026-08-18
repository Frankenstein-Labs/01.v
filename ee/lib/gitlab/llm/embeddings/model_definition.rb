# frozen_string_literal: true

module Gitlab
  module Llm
    module Embeddings
      class ModelDefinition
        include Gitlab::Utils::StrongMemoize

        Error = Class.new(StandardError)

        attr_reader :feature_name, :unit_primitive, :provider, :identifier, :use_cloud_aigw, :custom_model

        UNIT_PRIMITIVE_GENERATE_EMBEDDINGS_CODEBASE = 'generate_embeddings_codebase'

        FEATURE_CODE_EMBEDDINGS = :embeddings_code

        PROVIDER_GITLAB = "gitlab"
        PROVIDER_LITELLM = "litellm"

        TOKEN_LIMIT_EXCEEDED_PATTERNS = {
          'text_embedding_005_vertex' => /the input token count is \d+ but the model supports up to \d+/
        }.freeze

        def self.for_gitlab_provided_code_embeddings(identifier:, use_cloud_aigw: false)
          new(
            feature_name: FEATURE_CODE_EMBEDDINGS,
            unit_primitive: UNIT_PRIMITIVE_GENERATE_EMBEDDINGS_CODEBASE,
            provider: PROVIDER_GITLAB,
            identifier: identifier,
            use_cloud_aigw: use_cloud_aigw,
            custom_model: false
          )
        end

        def self.for_self_hosted_code_embedding(self_hosted_model_id:)
          new(
            feature_name: FEATURE_CODE_EMBEDDINGS,
            unit_primitive: UNIT_PRIMITIVE_GENERATE_EMBEDDINGS_CODEBASE,
            provider: PROVIDER_LITELLM,
            identifier: self_hosted_model_id,
            use_cloud_aigw: false,
            custom_model: true
          )
        end

        def initialize(
          feature_name:, unit_primitive:, provider:, identifier:,
          use_cloud_aigw: false, custom_model: false
        )
          @feature_name = feature_name
          @unit_primitive = unit_primitive
          @provider = provider
          @identifier = identifier
          @use_cloud_aigw = use_cloud_aigw
          @custom_model = custom_model
        end

        def aigw_base_url
          @aigw_base_url ||= use_cloud_aigw ? ::Gitlab::AiGateway.cloud_connector_url : ::Gitlab::AiGateway.url
        end

        def model_params
          return custom_model_params if custom_model

          standard_model_params
        end

        def catch_token_limit_exceeded_errors?
          TOKEN_LIMIT_EXCEEDED_PATTERNS.key?(identifier)
        end

        def token_limit_exceeded_message_pattern
          TOKEN_LIMIT_EXCEEDED_PATTERNS[identifier]
        end

        def gitlab_managed?
          provider == PROVIDER_GITLAB
        end

        def litellm_drop_params?
          provider == PROVIDER_LITELLM && custom_model
        end

        private

        def custom_model_params
          raise Error, "given identifier does not point to a self-hosted embedding model" if self_hosted_model.nil?

          # The `name` parameter must correspond to the model family defined as `self_hosted_model.model`.
          # At this point, the model family can only be "embedding"
          {
            provider: provider,
            name: self_hosted_model.model,
            identifier: self_hosted_model.identifier,
            endpoint: self_hosted_model.endpoint,
            api_key: self_hosted_model.api_token
          }
        end

        def standard_model_params
          {
            provider: provider,
            identifier: identifier
          }
        end

        def self_hosted_model
          ::Ai::SelfHostedModel.embedding.find_by_id(identifier.to_i)
        end
        strong_memoize_attr :self_hosted_model
      end
    end
  end
end
