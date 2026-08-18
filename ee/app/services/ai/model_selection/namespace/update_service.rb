# frozen_string_literal: true

module Ai
  module ModelSelection
    module Namespace
      class UpdateService
        include Gitlab::InternalEventsTracking

        def initialize(feature_setting, user, params)
          @feature_setting = feature_setting
          @user = user
          @params = params
          @namespace = feature_setting.namespace
        end

        def execute
          return unless ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)

          update_params = { offered_model_ref: params[:offered_model_ref] }

          catalog = ::Ai::ModelSelection::ModelDefinitions.fetch(user)

          return ServiceResponse.error(message: catalog.error_message) unless catalog.success?

          update_params[:model_definitions] = merge_dev_selectable_models(catalog.payload)

          if feature_setting.update(update_params)
            record_audit_event
            track_update_event

            ServiceResponse.success(payload: feature_setting)
          else
            ServiceResponse.error(payload: feature_setting,
              message: feature_setting.errors.full_messages.join(", "))
          end
        end

        private

        attr_accessor :feature_setting, :user, :namespace, :params

        def merge_dev_selectable_models(model_definitions)
          return model_definitions unless use_dev_overrides?

          ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser
            .new(model_definitions)
            .definitions_with_dev_selectable_models
        end

        def use_dev_overrides?
          return false unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

          user&.gitlab_team_member?
        end

        def record_audit_event
          model = params[:offered_model_ref]
          feature = feature_setting.feature
          scope_type = namespace.class.name
          scope_id = namespace.id
          text = "The LLM #{model} has been selected for the feature #{feature} of #{scope_type} with ID #{scope_id}"

          audit_context = {
            name: 'model_selection_feature_changed',
            author: user,
            scope: namespace,
            target: namespace,
            message: text,
            additional_details: {
              model_ref: model,
              feature: feature
            }
          }

          ::Gitlab::Audit::Auditor.audit(audit_context)
        end

        def track_update_event
          selection_scope_gid = namespace.to_global_id.to_s

          track_internal_event(
            'update_model_selection_feature',
            user: user,
            additional_properties: {
              label: params[:offered_model_ref],
              property: feature_setting.feature,
              selection_scope_gid: selection_scope_gid
            }
          )
        end
      end
    end
  end
end
