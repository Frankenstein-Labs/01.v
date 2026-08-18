# frozen_string_literal: true

module Admin
  module ApplicationSettings
    class SemanticSearchEmbeddingsPresenter # rubocop: disable Search/NamespacedClass -- this is for semantic search admin settings
      include Gitlab::Utils::StrongMemoize

      def initialize(
        instance_allows_user_model_selection:,
        user_has_update_model_permissions:,
        collection_record:,
        update_params: nil,
        tested_model_metadata: nil)
        @instance_allows_user_model_selection = instance_allows_user_model_selection
        @user_has_update_model_permissions = user_has_update_model_permissions
        @collection_record = collection_record
        @update_params = update_params
        @tested_model_metadata = tested_model_metadata
      end

      def user_can_update_model?
        instance_allows_user_model_selection && user_has_update_model_permissions
      end

      def current_model
        ::Ai::ActiveContext::Embedding.attach_model_name(
          collection_record.current_indexing_embedding_model
        )
      end
      strong_memoize_attr :current_model

      def next_model
        ::Ai::ActiveContext::Embedding.attach_model_name(
          collection_record.next_indexing_embedding_model
        )
      end
      strong_memoize_attr :next_model

      def form_display_model
        update_params || next_model || current_model
      end

      def disable_inputs?
        !user_can_update_model? || !!next_model
      end

      def tested_model_metadata_json
        return if tested_model_metadata.nil?

        tested_model_metadata.to_json
      end

      def show_chunk_strategy_fields?
        current_model.nil? && next_model.nil?
      end

      def show_chunk_strategy_text?
        !show_chunk_strategy_fields?
      end

      def chunk_strategy
        collection_record.chunk_strategy
      end

      def chunk_strategy_size
        collection_record.chunk_strategy_size
      end

      private

      attr_reader :instance_allows_user_model_selection,
        :user_has_update_model_permissions,
        :collection_record,
        :update_params,
        :tested_model_metadata
    end
  end
end
