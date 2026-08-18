# frozen_string_literal: true

module EE
  module API
    module MavenPackages
      extend ActiveSupport::Concern

      prepended do
        helpers ::EE::API::Helpers::DependencyFirewallHelpers

        helpers do
          extend ::Gitlab::Utils::Override

          override :present_package
          def present_package(package, format, package_file)
            if %w[md5 sha1].exclude?(format) &&
                ::Security::DependencyFirewall::Availability.feature_flag_enabled?(package.project)
              enforce_dependency_firewall!(
                project: package.project,
                pkg_type: 'maven',
                name: package.name,
                version: package.version,
                operation: ::Security::DependencyFirewall::EnforcementService::PACKAGE_DOWNLOAD
              )
            end

            super
          end

          override :enforce_dependency_firewall_on_upload!
          def enforce_dependency_firewall_on_upload!(package_name, version)
            return unless ::Security::DependencyFirewall::Availability.feature_flag_enabled?(user_project)

            _, format = extract_format(params[:file_name])
            return if %w[md5 sha1].include?(format)

            enforce_dependency_firewall!(
              project: user_project,
              pkg_type: 'maven',
              name: package_name,
              version: version,
              operation: ::Security::DependencyFirewall::EnforcementService::PACKAGE_UPLOAD
            )
          end
        end
      end
    end
  end
end
