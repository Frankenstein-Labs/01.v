# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    class Client
      def self.url(user:)
        self_hosted_url || cloud_connected_url(user: user)
      end

      def self.cloud_connected_url(user:)
        Gitlab.config.duo_workflow.service_url || default_service_url(user: user)
      end

      def self.default_service_url(user:)
        if Feature.enabled?(:duo_workflow_cloud_connector_url, user)
          return "#{::CloudConnector::Config.host}:#{::CloudConnector::Config.port}"
        end

        subdomain = ::CloudConnector::Config.host.include?('staging') ? '.staging' : ''

        # Cloudflare has been disabled until
        # gets resolved https://gitlab.com/gitlab-org/gitlab/-/issues/509586
        # "#{::CloudConnector::Config.host}:#{::CloudConnector::Config.port}"
        "duo-workflow-svc#{subdomain}.runway.gitlab.net:#{::CloudConnector::Config.port}"
      end

      def self.url_for(feature_setting:, user:)
        if feature_setting&.self_hosted?
          self_hosted_url
        else
          cloud_connected_url(user: user)
        end
      end

      def self.self_hosted_url
        ::Gitlab::CurrentSettings.duo_agent_platform_service_url.presence
      end

      def self.secure?(feature_setting: nil)
        return ::Gitlab::CurrentSettings.self_hosted_duo_agent_platform_service_secure if feature_setting&.self_hosted?

        !!Gitlab.config.duo_workflow.secure
      end

      def self.debug_mode?
        !!Gitlab.config.duo_workflow.debug
      end

      def self.cloud_connector_headers(
        user:, feature_setting: nil, tool_access_policies: {}, subject: user,
        governing_namespace_id: nil, **kwargs)
        token = Gitlab::AiGateway.cloud_connector_token(
          :duo_agent_platform,
          user,
          feature_setting: feature_setting,
          root_namespace_id: governing_namespace_id,
          extra_claims: { tool_access_policies: tool_access_policies.to_json }
        )

        Gitlab::AiGateway
          .public_headers(user: user, feature_setting: feature_setting, ai_feature_name: :duo_workflow,
            unit_primitive_name: :duo_workflow_execute_workflow, subject: subject,
            governing_namespace_id: governing_namespace_id, **kwargs)
          .transform_keys(&:downcase)
          .merge(
            'authorization' => "Bearer #{token}",
            'x-gitlab-authentication-type' => 'oidc'
          )
      end

      def self.metadata(user, namespace: nil, project: nil)
        root_namespace = namespace&.root_ancestor

        {
          extended_logging: enable_extended_logging?(user, namespace: namespace),
          is_team_member:
            ::Gitlab::Tracking::StandardContext.new.gitlab_team_member?(user&.id),
          tool_approval_for_session_enabled: tool_approval_for_session_enabled?(namespace: namespace,
            project: project),
          rootNamespaceId: root_namespace&.id&.to_s
        }
      end

      private_class_method def self.tool_approval_for_session_enabled?(namespace: nil, project: nil)
        return project.project_setting.tool_approval_for_session_enabled? if project

        return false unless namespace

        namespace.namespace_settings&.tool_approval_for_session_enabled?
      end

      def self.enable_extended_logging?(user, namespace: nil)
        # For a self-hosted Duo instance, return the value of the
        # instance setting.
        return ::Gitlab::CurrentSettings.enabled_instance_verbose_ai_logs if self_hosted_url

        # Check if the feature flag is enabled for the user - this overrides namespace check
        return true if Feature.enabled?(:duo_workflow_extended_logging, user)

        # If a namespace is provided, return the value of the namespace setting
        return namespace.ai_usage_data_collection_enabled if namespace

        false
      end
    end
  end
end
