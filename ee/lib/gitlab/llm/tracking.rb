# frozen_string_literal: true

module Gitlab
  module Llm
    class Tracking
      USER_AGENT_CLIENTS = {
        UsageDataCounters::VSCodeExtensionActivityUniqueCounter::VS_CODE_USER_AGENT_REGEX =>
          'vscode',
        UsageDataCounters::JetBrainsPluginActivityUniqueCounter::JETBRAINS_USER_AGENT_REGEX =>
          'jetbrains',
        UsageDataCounters::JetBrainsBundledPluginActivityUniqueCounter::JETBRAINS_BUNDLED_USER_AGENT_REGEX =>
          'jetbrains_bundled',
        UsageDataCounters::VisualStudioExtensionActivityUniqueCounter::VISUAL_STUDIO_EXTENSION_USER_AGENT_REGEX =>
          'visual_studio',
        UsageDataCounters::NeovimPluginActivityUniqueCounter::NEOVIM_PLUGIN_USER_AGENT_REGEX =>
          'neovim',
        UsageDataCounters::GitLabCliActivityUniqueCounter::GITLAB_CLI_USER_AGENT_REGEX =>
          'gitlab_cli'
      }.freeze

      WEB_CLIENT = 'web'
      WEB_IDE_CLIENT = 'web_ide'

      PLATFORM_VS_CODE = 'vs_code_extension'

      def self.event_for_ai_message(category, action, ai_message:)
        ::Gitlab::Tracking.event(
          category,
          action,
          label: ai_message.ai_action.to_s,
          property: ai_message.request_id,
          user: ai_message.user,
          client: determine_client(ai_message)
        )
      end

      def self.client_for_user_agent(user_agent)
        return unless user_agent.present?

        USER_AGENT_CLIENTS.find { |regex, _client| user_agent.match?(regex) }&.last || WEB_CLIENT
      end

      def self.determine_client(ai_message)
        client = client_for_user_agent(ai_message.context.user_agent)
        return client unless client == WEB_CLIENT

        # Web IDE has the same `user agent` as web, and same `platform_origin` as the VS Code IDE.
        # So we need to look at both factors to distinguish it.
        ai_message.platform_origin == PLATFORM_VS_CODE ? WEB_IDE_CLIENT : WEB_CLIENT
      end

      private_class_method :determine_client
    end
  end
end
