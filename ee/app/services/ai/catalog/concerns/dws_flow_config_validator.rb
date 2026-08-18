# frozen_string_literal: true

module Ai
  module Catalog
    module Concerns
      module DwsFlowConfigValidator
        extend ActiveSupport::Concern

        private

        def validate_flow_config_with_dws(definition_hash)
          return ServiceResponse.success if definition_hash.blank?

          config = definition_hash.except('yaml_definition')
          dws_client.validate_flow_config(flow_config: config)
        end

        def dws_client
          feature_setting = resolve_feature_setting

          ::Ai::DuoWorkflow::DuoWorkflowService::Client.new(
            duo_workflow_service_url: ::Gitlab::DuoWorkflow::Client.url_for(
              feature_setting: feature_setting, user: current_user
            ),
            current_user: current_user,
            secure: ::Gitlab::DuoWorkflow::Client.secure?(feature_setting: feature_setting)
          )
        end

        def resolve_feature_setting
          ::Ai::FeatureSettingSelectionService.new(
            current_user,
            ::Ai::ModelSelection::FeaturesConfigurable.workflow_feature_name,
            project.root_ancestor
          ).execute.payload
        end

        def set_dws_validated_on_version(item_version)
          item_version.dws_flow_config_validated = true
        end
      end
    end
  end
end
