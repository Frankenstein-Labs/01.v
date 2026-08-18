# frozen_string_literal: true

module EE
  module API
    module Helpers
      module DependencyFirewallHelpers
        WARNING_HEADER = 'X-Gitlab-Dependency-Firewall-Warning'

        def enforce_dependency_firewall!(project:, pkg_type:, name:, version:, operation:)
          # Exceptions from firewall_check (invalid params, infrastructure failures) are intentionally
          # not rescued here. They propagate as 500s, which will trigger Prometheus alerting and contribute
          # to the error budget. See: https://gitlab.com/gitlab-org/gitlab/-/work_items/593923
          result = ::Security::DependencyFirewall::EnforcementService.firewall_check(
            project: project,
            pkg_type: pkg_type,
            name: name,
            version: version,
            operation: operation,
            current_user: current_user
          )

          status = result.reason || result.payload&.dig(:status)

          case status
          when ::Security::DependencyFirewall::EnforcementService::SUCCESS_WARNING
            set_dependency_firewall_warning_header(result.payload&.dig(:message))
          when ::Security::DependencyFirewall::EnforcementService::SUCCESS_BLOCKED
            render_structured_api_error!(
              { message: result.message.presence || 'Dependency Firewall policy violation',
                error: 'Dependency Firewall policy violation' },
              403
            )
          end
        end

        private

        def set_dependency_firewall_warning_header(message)
          message = message.to_s
          return if message.empty?

          sanitized = message.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, '').gsub(/[\r\n]+/, ' ').strip
          return if sanitized.empty?

          header[WARNING_HEADER] = sanitized
        end
      end
    end
  end
end
