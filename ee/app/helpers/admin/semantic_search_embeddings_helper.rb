# frozen_string_literal: true

module Admin
  module SemanticSearchEmbeddingsHelper # rubocop: disable Search/NamespacedClass -- this is for semantic search admin settings
    def collection_name(collection_key)
      collection_key.to_s.titleize
    end

    def embedding_model_display_name(model)
      [
        model_type_display(model[:model_type]),
        model_name(model),
        model[:dimensions]
      ].compact.join(" | ")
    end

    def embedding_models_grouped_options(current_model, self_hosted_embedding_models)
      grouped_options = [
        gitlab_managed_model_options_group,
        self_hosted_model_options_group(self_hosted_embedding_models)
      ].compact

      unless current_model
        grouped_options.unshift(
          [
            "No model selected",
            [["--", nil]]
          ]
        )
      end

      grouped_options
    end

    def embedding_model_key(model)
      return if model.blank?

      "#{model[:model_type]}__#{model[:model_ref]}"
    end

    def embedding_model_dimensions(model)
      return if model.blank?

      model[:dimensions]
    end

    def chunk_strategy_options
      ::Ai::ActiveContext::Embedding::CHUNK_STRATEGIES.map do |strategy|
        [strategy.to_s.titleize, strategy.to_s]
      end
    end

    def chunking_strategy_display(chunk_strategy, chunk_strategy_size)
      return default_chunking_strategy_display if chunk_strategy.blank?

      [
        chunk_strategy.to_s.titleize,
        chunk_strategy_size.presence&.to_i
      ].compact.join(' | ')
    end

    private

    def default_chunking_strategy_display
      [
        ::Ai::ActiveContext::Embedding::DEFAULT_CHUNK_STRATEGY.to_s.titleize,
        ::Ai::ActiveContext::Embedding::DEFAULT_CHUNK_STRATEGY_SIZE
      ].join(' | ')
    end

    def model_type_display(model_type)
      return unless model_type

      model_type.to_s.tr('_', '-').capitalize
    end

    def model_name(model)
      model[:model_name] || 'Unknown model'
    end

    def gitlab_managed_model_options_group
      model_type = ::Ai::ActiveContext::Embedding::MODEL_TYPE_GITLAB_MANAGED
      model_options = ::Ai::ActiveContext::Embedding.gitlab_managed_models_lookup.map do |k, v|
        [
          v[:model_name],
          embedding_model_key(model_type: model_type, model_ref: k)
        ]
      end

      [model_type_display(model_type), model_options.sort_by(&:first)]
    end

    def self_hosted_model_options_group(self_hosted_embedding_models)
      return if self_hosted_embedding_models.blank?

      model_type = ::Ai::ActiveContext::Embedding::MODEL_TYPE_SELF_HOSTED
      model_options = self_hosted_embedding_models.map do |emb|
        [
          emb.name,
          embedding_model_key(model_type: model_type, model_ref: emb.id)
        ]
      end

      [model_type_display(model_type), model_options.sort_by(&:first)]
    end
  end
end
