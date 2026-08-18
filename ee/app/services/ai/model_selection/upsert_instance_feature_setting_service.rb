# frozen_string_literal: true

module Ai
  module ModelSelection
    class UpsertInstanceFeatureSettingService
      include Gitlab::InternalEventsTracking

      def initialize(user, feature, offered_model_ref)
        @feature = feature
        @offered_model_ref = offered_model_ref
        @user = user
        @setting = nil
      end

      def execute
        catalog = ::Ai::ModelSelection::ModelDefinitions.fetch(@user)

        return ServiceResponse.error(message: catalog.error_message) unless catalog.success?

        model_definitions = catalog.payload

        @setting = ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting.find_or_initialize_by_feature(
          @feature
        )

        if @setting.update(offered_model_ref: @offered_model_ref, model_definitions: model_definitions)
          audit_event
          track_update_event
          ServiceResponse.success(payload: @setting)
        else
          ServiceResponse.error(
            payload: @setting,
            message: @setting.errors.full_messages.join(", ")
          )
        end
      end

      def audit_event
        audit_context = {
          name: 'self_hosted_model_feature_changed',
          author: @user,
          scope: Gitlab::Audit::InstanceScope.new,
          target: @setting,
          message: "Feature #{@feature} changed to vendored #{@offered_model_ref}"
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def track_update_event
        track_internal_event(
          'update_model_selection_feature',
          user: @user,
          additional_properties: {
            label: @offered_model_ref,
            property: @feature.to_s,
            selection_scope_gid: nil
          }
        )
      end
    end
  end
end
