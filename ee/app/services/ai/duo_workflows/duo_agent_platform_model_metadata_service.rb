# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class DuoAgentPlatformModelMetadataService
      include ::Gitlab::Utils::StrongMemoize

      def initialize(
        feature_name:,
        root_namespace: nil,
        current_user: nil,
        user_selected_model_identifier: nil
      )
        @root_namespace = root_namespace
        @current_user = current_user
        @user_selected_model_identifier = user_selected_model_identifier.to_s
        @feature_name = feature_name&.to_sym
      end

      def execute
        return resolve_self_managed_model_metadata if self_managed?

        resolve_gitlab_com_model_metadata
      end

      private

      attr_reader :root_namespace, :current_user, :user_selected_model_identifier, :feature_name

      def self_managed?
        !::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end

      def duo_agent_platform
        ::Ai::FeatureSetting.find_by_feature(feature_name)
      end
      strong_memoize_attr :duo_agent_platform

      def duo_agent_platform_in_self_hosted_duo?
        # There is a `disabled` option for Duo Self-Hosted.
        # We need to consider this case otherwise it resolves to
        # cloud-connected models.
        return true if duo_agent_platform&.disabled?

        duo_agent_platform&.self_hosted?
      end

      def resolve_self_managed_model_metadata
        return resolve_self_hosted_duo_model_metadata if duo_agent_platform_in_self_hosted_duo?

        resolve_cloud_connected_model_metadata
      end

      # Self-Hosted Duo Priority:
      # 1. Self-hosted feature setting (admin-configured models only)
      # Note: No user model selection - limited to what admin sets up
      def resolve_self_hosted_duo_model_metadata
        feature_setting = duo_agent_platform

        return {} if feature_setting.nil? || feature_setting.disabled?

        model_metadata_from_setting(feature_setting)
      end

      # Cloud-Connected Self-Managed Priority (same user empowerment as GitLab.com):
      # 1. Instance-level model selection (admin sets instance defaults)
      # 2. User model selection (users can override instance defaults)
      def resolve_cloud_connected_model_metadata
        # Priority 1: Instance-level model selection
        instance_setting = ::Ai::ModelSelection::InstanceModelSelectionFeatureSetting
                            .find_or_initialize_by_feature(feature_name)

        return {} unless instance_setting

        resolve_model_metadata_with_user_selection(instance_setting)
      end

      # GitLab.com Priority:
      # 1. Namespace-level model selection (organization/group defaults)
      # 2. User model selection (users can override namespace defaults)
      def resolve_gitlab_com_model_metadata
        return {} unless root_namespace

        # Priority 1: Namespace-level model selection
        namespace_setting = ::Ai::ModelSelection::NamespaceFeatureSetting
                             .find_or_initialize_by_feature(root_namespace, feature_name)

        return {} unless namespace_setting

        resolve_model_metadata_with_user_selection(namespace_setting)
      end

      def resolve_model_metadata_with_user_selection(setting)
        setting_metadata = model_metadata_from_setting(setting)

        return setting_metadata if do_not_consider_user_selected_model?(setting)

        # Priority 2: User model selection
        user_selected_model_metadata(setting)
      end

      def model_metadata_from_setting(setting_record)
        ::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata.new(
          feature_setting: setting_record
        ).execute
      end

      def do_not_consider_user_selected_model?(setting)
        user_model_selection(setting)
          .do_not_consider_user_selected_model?(user_selected_model_identifier)
      end

      def user_model_selection(setting)
        strong_memoize_with(:user_model_selection, setting) do
          ::Ai::ModelSelection::UserModelSelection.for(
            current_user, feature_setting: setting
          )
        end
      end

      def user_selected_model_metadata(setting)
        record = setting.build_with_offered_model_ref(user_selected_model_identifier)

        model_metadata_from_setting(record)
      end
    end
  end
end
