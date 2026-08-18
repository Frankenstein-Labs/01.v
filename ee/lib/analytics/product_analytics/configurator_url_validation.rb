# frozen_string_literal: true

module Analytics
  module ProductAnalytics
    module ConfiguratorUrlValidation
      def validate_url!(url)
        ::Gitlab::HTTP_V2::UrlBlocker.validate!(
          url,
          allow_localhost: allow_local_requests?,
          allow_local_network: allow_local_requests?,
          schemes: %w[http https],
          deny_all_requests_except_allowed: ::Gitlab::CurrentSettings.deny_all_requests_except_allowed?,
          outbound_local_requests_allowlist: ::Gitlab::CurrentSettings.outbound_local_requests_whitelist # rubocop:disable Naming/InclusiveLanguage -- existing setting
        )
      end

      def allow_local_requests?
        ::Gitlab::CurrentSettings.allow_local_requests_from_web_hooks_and_services?
      end

      def configurator_url(project)
        ::ProductAnalytics::Settings.for_project(project).product_analytics_configurator_connection_string
      end
    end
  end
end
