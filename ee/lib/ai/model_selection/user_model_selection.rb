# frozen_string_literal: true

module Ai
  module ModelSelection
    class UserModelSelection
      include ::Gitlab::Utils::StrongMemoize

      def self.for(current_user, feature_setting:)
        if feature_setting&.self_hosted? && feature_setting.self_hosted_model.present?
          return SelfHostedModelSelection.new(feature_setting)
        end

        new(current_user, feature_setting: feature_setting)
      end

      def initialize(current_user, feature_setting:)
        @current_user = current_user
        @feature_setting = feature_setting
      end

      def default_model
        return unless user_selection_available?
        return decorator.default_model unless allowlist_feature_enabled?

        model_for(feature_setting.currently_chosen_model_ref(model_definition_parser))
      end

      def selectable_models
        return [] unless user_selection_available?
        return decorator.selectable_models unless allowlist_feature_enabled?

        allowed_refs = feature_setting.effective_allowed_model_refs(model_definition_parser)
        decorator.selectable_models.select { |model| allowed_refs.include?(model[:ref]) }
      end
      strong_memoize_attr :selectable_models

      def pinned_model
        return unless user_selection_available?
        return unless effectively_pinned?

        model_for(feature_setting.offered_model_ref)
      end

      def do_not_consider_user_selected_model?(user_selected_model_identifier)
        return true unless feature_setting
        return true unless agentic_chat_feature?

        effectively_pinned? ||
          !user_selected_model_allowed?(user_selected_model_identifier)
      end

      private

      attr_reader :current_user, :feature_setting

      # The admin's chosen model is a hard pin (disabling user selection) only when
      # the allowlist is not active. With the allowlist on it is just a default, so
      # user selection stays enabled and the pick is validated against the allowlist.
      def effectively_pinned?
        feature_setting.pinned_model? && !allowlist_feature_enabled?
      end

      def allowlist_feature_available?
        feature_setting.model_allowlist_supported?
      end

      def allowlist_feature_enabled?
        return false unless allowlist_feature_available?

        feature_setting.model_allowlist_enabled
      end
      strong_memoize_attr :allowlist_feature_enabled?

      def agentic_chat_feature?
        return false unless feature_setting

        feature_setting.feature.to_sym == ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name
      end

      def user_selected_model_allowed?(ref)
        ref.present? && selectable_models.any? { |model| model[:ref] == ref }
      end

      def user_selection_available?
        feature_setting.present? &&
          decorator.present? &&
          feature_setting.user_model_selection_available?
      end
      strong_memoize_attr :user_selection_available?

      def model_for(ref)
        return if ref.blank?

        decorator.selectable_models.find { |model| model[:ref] == ref }
      end

      def decorator
        return unless feature_setting
        return unless model_definitions

        ::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting
          .decorate([feature_setting], model_definitions: model_definitions, current_user: current_user)
          .find { |object| object.feature_setting&.feature&.to_sym == feature_setting.feature.to_sym }
      end
      strong_memoize_attr :decorator

      def model_definitions
        model_definitions_catalog.payload
      end

      def model_definition_parser
        model_definitions_catalog.parser
      end
      strong_memoize_attr :model_definition_parser

      def model_definitions_catalog
        ::Ai::ModelSelection::ModelDefinitions.fetch(current_user)
      end
      strong_memoize_attr :model_definitions_catalog
    end
  end
end
