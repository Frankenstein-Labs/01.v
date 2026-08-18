# frozen_string_literal: true

module Ai
  module ActiveContext
    module Embeddings
      class ModelFactory
        MissingModelDefinition = Class.new(StandardError)
        UnexpectedModelConfiguration = Class.new(StandardError)
        UnsupportedModelConfiguration = Class.new(StandardError)

        def self.for(model_metadata, search: false)
          new(model_metadata, search: search).execute
        end

        def initialize(model_metadata, search: false)
          @model_metadata = model_metadata
          @search = search
        end

        def execute
          return if model_metadata.nil?

          validate_model_ref_and_field!
          validate_model_type!

          return gitlab_managed_model if ::Ai::ActiveContext.gitlab_selects_embedding_model?

          user_selected_model
        end

        private

        attr_reader :model_metadata, :search

        def user_selected_model
          case model_type
          when ::Ai::ActiveContext::Embedding::MODEL_TYPE_GITLAB_MANAGED
            gitlab_managed_model(use_cloud_aigw: true)
          when ::Ai::ActiveContext::Embedding::MODEL_TYPE_SELF_HOSTED
            self_hosted_model
          else
            raise(
              UnsupportedModelConfiguration,
              "`model_type` must be one of the following values: " \
                "#{::Ai::ActiveContext::Embedding::MODEL_TYPES.join('|')}"
            )
          end
        end

        def gitlab_managed_model(use_cloud_aigw: false)
          validate_gitlab_managed_model!

          model_definition = ::Gitlab::Llm::Embeddings::ModelDefinition.for_gitlab_provided_code_embeddings(
            identifier: model_ref,
            use_cloud_aigw: use_cloud_aigw
          )

          ::ActiveContext::EmbeddingModel.new(
            field: embedding_field,
            model_ref: model_ref,
            model_type: ::Ai::ActiveContext::Embedding::MODEL_TYPE_GITLAB_MANAGED,
            dimensions: embedding_dimensions,
            llm_class: ::Gitlab::Llm::Embeddings::CodeEmbeddings,
            llm_params: {
              model_definition: model_definition,
              batch_size: ::Ai::ActiveContext::Embedding.embeddings_request_batch_size(model_metadata),
              search: search
            }
          )
        end

        def self_hosted_model
          validate_self_hosted_model!

          model_definition = ::Gitlab::Llm::Embeddings::ModelDefinition.for_self_hosted_code_embedding(
            self_hosted_model_id: model_ref
          )

          ::ActiveContext::EmbeddingModel.new(
            field: embedding_field,
            model_ref: model_ref,
            model_type: ::Ai::ActiveContext::Embedding::MODEL_TYPE_SELF_HOSTED,
            dimensions: embedding_dimensions,
            llm_class: ::Gitlab::Llm::Embeddings::CodeEmbeddings,
            llm_params: {
              model_definition: model_definition,
              batch_size: ::Ai::ActiveContext::Embedding.embeddings_request_batch_size(model_metadata),
              search: search
            }
          )
        end

        def model_ref
          @model_ref ||= model_metadata[:model_ref]
        end

        def model_type
          @model_type ||= model_metadata[:model_type]&.to_sym
        end

        def embedding_field
          @embedding_field ||= model_metadata[:field]
        end

        def embedding_dimensions
          @embedding_dimensions ||= model_metadata[:dimensions]
        end

        def validate_model_ref_and_field!
          return if model_ref.present? && embedding_field.present?

          raise UnexpectedModelConfiguration, "`model_metadata` must have a `model_ref` and `field`"
        end

        def validate_model_type!
          return if ::Ai::ActiveContext.gitlab_selects_embedding_model? || model_type.present?

          raise(
            UnexpectedModelConfiguration,
            "`model_metadata` must have a `model_type` if Duo Self-Hosted is configured"
          )
        end

        def validate_gitlab_managed_model!
          return if ::Ai::ActiveContext::Embedding.gitlab_managed_models_lookup.has_key?(model_ref)

          raise MissingModelDefinition, "Missing definitions for Gitlab-managed model: #{model_ref}"
        end

        def validate_self_hosted_model!
          record = ::Ai::SelfHostedModel.find_by_id(model_ref.to_i)

          raise MissingModelDefinition, "Self-hosted model with ID '#{model_ref}' not found" if record.nil?
          raise UnexpectedModelConfiguration, "Self-hosted model must have 'embedding' family" unless record.embedding?
        end
      end
    end
  end
end
