# frozen_string_literal: true

module EE
  module Packages
    module Npm
      module ProcessTemporaryPackageFileService
        extend ::Gitlab::Utils::Override

        # Enforces the Dependency Firewall on publish. Runs in the async worker, so
        # the version is read from the already-parsed publish document (no size-limited
        # synchronous parse). A blocked package returns an error ServiceResponse, which
        # the worker surfaces as a package error on the Packages page, and the package
        # is never promoted from its temporary record.
        override :enforce_dependency_firewall
        def enforce_dependency_firewall(json_doc)
          return unless ::Security::DependencyFirewall::Availability.feature_flag_enabled?(project)

          name = json_doc[:name]
          return if name.blank?

          normalized_name = ::Sbom::PackageUrl::Normalizer.new(type: 'npm', text: name).normalize_name

          Array(json_doc[:versions]&.keys).each do |version|
            result = ::Security::DependencyFirewall::EnforcementService.firewall_check(
              project: project,
              pkg_type: 'npm',
              name: normalized_name,
              version: version,
              operation: ::Security::DependencyFirewall::EnforcementService::PACKAGE_UPLOAD,
              current_user: current_user
            )

            next unless result.reason == ::Security::DependencyFirewall::EnforcementService::SUCCESS_BLOCKED

            return ServiceResponse.error(
              message: result.message.presence || 'Dependency Firewall policy violation',
              reason: :dependency_firewall_policy_violation
            )
          end

          nil
        end
      end
    end
  end
end
