# frozen_string_literal: true

module Admin
  module ApplicationSettings
    class SemanticSearchEmbeddingsController < Admin::ApplicationController # rubocop: disable Search/NamespacedClass -- this is for semantic search admin settings
      include ::Ai::ActiveContext::Concerns::Loggable

      feature_category :global_search
      urgency :low

      before_action :redirect_if_semantic_search_unavailable
      before_action :collection_key, only: [:show, :update, :test_model_configuration]
      before_action :redirect_if_collection_unavailable, only: [:show, :update, :test_model_configuration]
      before_action :redirect_unless_feature_setting_allowed, only: [:show, :update, :test_model_configuration]
      before_action :fetch_user_update_ability, only: [:show, :update, :test_model_configuration]
      before_action :fetch_self_hosted_embedding_models, only: [:show, :update]

      COLLECTION_CLASS_LOOKUP = {
        code: ::Ai::ActiveContext::Collections::Code
      }.freeze

      def show
        build_presenter

        return unless validate_user_can_update(flash_type: :notice)
        return unless collection_record.next_indexing_embedding_model

        flash.now[:notice] = "You cannot update the model at this time. " \
          "There is already a next embedding model."
      end

      def update
        pre_update_checks_satisfied = validate_user_can_update && require_update_params

        fetch_tested_model_metadata_from_params

        update_embedding_model if pre_update_checks_satisfied

        build_presenter(@update_params, @tested_model_metadata)

        render :show
      end

      def test_model_configuration
        unless validate_user_can_update
          return render json: { success: false, message: flash[:alert] }, status: :unauthorized
        end

        unless require_update_params
          return render json: { success: false, message: flash[:alert] }, status: :bad_request
        end

        response = test_embedding_model

        if response.error?
          return render json: { success: false, message: response.message }, status: :unprocessable_entity
        end

        render json: { success: true, tested_model_metadata: response.payload[:tested_model_metadata] }
      end

      private

      def collection_key
        @collection_key = params.require(:id).to_sym
      end

      def collection_class
        COLLECTION_CLASS_LOOKUP[@collection_key]
      end

      def collection_record
        @collection_record ||= collection_class&.collection_record
      end

      def redirect_if_semantic_search_unavailable
        if ::Ai::ActiveContext.semantic_search_available? &&
            ::ActiveContext.adapter&.connection.present?
          return
        end

        redirect_to search_admin_application_settings_path
      end

      def redirect_if_collection_unavailable
        return if collection_record.present?

        redirect_to search_admin_application_settings_path
      end

      def redirect_unless_feature_setting_allowed
        return if ::Ai::ActiveContext::Embedding.feature_setting_allowed?(collection_record.name_without_prefix)

        redirect_to search_admin_application_settings_path
      end

      def fetch_user_update_ability
        @instance_allows_user_model_selection = ::Ai::ActiveContext.user_selects_embedding_model?
        @user_has_update_model_permissions = current_user.can?(:manage_instance_model_selection) # rubocop: disable Gitlab/Authz/PermissionCheck -- there is no specific permission
      end

      def fetch_self_hosted_embedding_models
        @self_hosted_embedding_models = ::Ai::ActiveContext::Embedding.self_hosted_models
      end

      def build_presenter(update_params = nil, tested_model_metadata = nil)
        presenter_params = {
          instance_allows_user_model_selection: @instance_allows_user_model_selection,
          user_has_update_model_permissions: @user_has_update_model_permissions,
          collection_record: collection_record.reset
        }
        presenter_params[:update_params] = update_params if update_params
        presenter_params[:tested_model_metadata] = tested_model_metadata if tested_model_metadata

        @presenter = Admin::ApplicationSettings::SemanticSearchEmbeddingsPresenter.new(
          **presenter_params
        )
      end

      def validate_user_can_update(flash_type: :alert)
        unless @instance_allows_user_model_selection
          flash.now[flash_type] = "Model selection by user is not available in this GitLab instance."
          return false
        end

        unless @user_has_update_model_permissions
          flash.now[flash_type] = "You do not have sufficient permissions to update the model."
          return false
        end

        true
      end

      def require_update_params
        model_details = params.require(:embedding_model).split("__")
        embedding_dimensions = params.require(:embedding_dimensions)

        @update_params = {
          model_type: model_details.first.to_sym,
          model_ref: model_details.second.to_s,
          dimensions: embedding_dimensions.to_i
        }

        true
      rescue ActionController::ParameterMissing => e
        flash.now[:alert] = "Error: #{e.message}."
        false
      end

      def chunk_strategy_params
        permitted = params.permit(:chunk_strategy, :chunk_strategy_size)
        {
          chunk_strategy: permitted[:chunk_strategy].presence,
          chunk_strategy_size: permitted[:chunk_strategy_size].presence&.to_i
        }
      end

      def fetch_tested_model_metadata_from_params
        metadata_json = params.permit(:tested_model_metadata)[:tested_model_metadata]
        return if metadata_json.blank?

        parsed_metadata = Gitlab::Json.safe_parse(metadata_json)

        @tested_model_metadata = {
          model_type: parsed_metadata['model_type'].to_sym,
          model_ref: parsed_metadata['model_ref'].to_s,
          dimensions: parsed_metadata['dimensions'].to_i
        }
      end

      def test_embedding_model
        ::Ai::ActiveContext::TestEmbeddingModelService.new(
          collection_class: collection_class,
          **@update_params
        ).execute
      rescue StandardError => e
        logger.error(
          build_structured_payload(
            collection: @collection_key,
            error_class: e.class.name,
            message: e.message,
            **@update_params
          )
        )

        ServiceResponse.error(message: 'unknown error')
      end

      def update_embedding_model
        skip_embeddings_request_test = (@update_params == @tested_model_metadata)

        ::Ai::ActiveContext::EmbeddingModelActivationService.new(
          collection_class: collection_class,
          skip_embeddings_request_test: skip_embeddings_request_test,
          user: current_user,
          **@update_params,
          **chunk_strategy_params
        ).execute!

        flash_update_successful
      rescue StandardError => e
        logger.error(
          build_structured_payload(
            collection: @collection_key,
            error_class: e.class.name,
            message: e.message,
            **@update_params
          )
        )

        flash_update_failed(e)
      end

      def flash_update_successful
        unless collection_record.current_indexing_embedding_model
          return flash.now[:notice] = 'Embedding model has been set.'
        end

        flash.now[:notice] = 'Embeddings updated and backfill started.'
      end

      def flash_update_failed(error)
        error_detail = error.message if error.is_a?(::Ai::ActiveContext::EmbeddingModelActivationService::Error)
        error_detail ||= 'unknown error'

        flash.now[:alert] = "Update failed: #{error_detail}."
      end
    end
  end
end
