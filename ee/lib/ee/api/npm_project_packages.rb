# frozen_string_literal: true

module EE
  module API
    module NpmProjectPackages
      extend ActiveSupport::Concern

      prepended do
        helpers ::EE::API::Helpers::DependencyFirewallHelpers

        helpers do
          extend ::Gitlab::Utils::Override
          include ::API::Helpers::RelatedResourcesHelpers

          # Name is normalized so policy rules match regardless of how the package
          # was requested; the `package&.project` guard is defensive (the finder
          # returns a package before this runs).
          override :enforce_dependency_firewall_on_download!
          def enforce_dependency_firewall_on_download!(package)
            return unless package&.project
            return unless ::Security::DependencyFirewall::Availability.feature_flag_enabled?(package.project)

            enforce_dependency_firewall!(
              project: package.project,
              pkg_type: 'npm',
              name: ::Sbom::PackageUrl::Normalizer.new(type: 'npm', text: package.name).normalize_name,
              version: package.version,
              operation: ::Security::DependencyFirewall::EnforcementService::PACKAGE_DOWNLOAD
            )
          end

          # Layers the Dependency Firewall on the CE tarball forward. When DFW is
          # licensed + enabled, derive the version from the filename and firewall-check
          # (403 on block; fail closed with a 404 if the version can't be parsed), then
          # fall through to the CE `super`, which issues the 302 (or its own 404 when
          # forwarding is off). When DFW is off, skip straight to the CE forward so
          # GitLab tarball URLs already baked into committed lockfiles keep resolving
          # after a license/flag lapse.
          override :forward_npm_tarball_download_or_404!
          def forward_npm_tarball_download_or_404!(project, package_name, file_name)
            if forward_npm_candidate?(project)
              version = version_from_filename(package_name, file_name)
              not_found!('Package') if version.blank?

              enforce_dependency_firewall!(
                project: project,
                pkg_type: 'npm',
                name: ::Sbom::PackageUrl::Normalizer.new(type: 'npm', text: package_name).normalize_name,
                version: version,
                operation: ::Security::DependencyFirewall::EnforcementService::PACKAGE_DOWNLOAD
              )
            end

            super
          end

          # When the package isn't hosted locally and forwarding enforcement is on,
          # hand the upstream packument off to Workhorse via `send-url` with a
          # transform that rewrites each `dist.tarball` back to the GitLab tarball
          # route (so the follow-up download is firewall-checked). Otherwise defer to
          # CE, which serves local metadata or 302-redirects upstream.
          override :present_or_forward_npm_metadata!
          def present_or_forward_npm_metadata!(package_name, packages)
            return super unless project_or_nil && forward_npm_candidate?(project_or_nil)
            return super unless packages.empty?

            authorize_read_package!(project)

            # Preserve the forwarding metric the CE `redirect_registry_request` path
            # emits, since the Workhorse hand-off replaces that redirect.
            ::Gitlab::Tracking.event(options[:for].name, 'npm_request_forward')

            header(*::Gitlab::Workhorse.send_url(
              registry_url(:npm, package_name: package_name),
              headers: { 'Accept' => headers['Accept'] }.compact,
              ssrf_filter: true,
              allow_localhost: Rails.env.development?,
              response_statuses: { error: :bad_gateway, timeout: :bad_gateway },
              restrict_forwarded_response_headers: { enabled: true, allow_list: %w[Content-Type ETag] },
              transform_config: {
                key: 'tarball',
                from: registry_base_url(:npm),
                to: expose_url("/api/v4/projects/#{project.id}/packages/npm/")
              }
            ))
            # Workhorse produces the real response from the send-url instruction; emit
            # an empty binary body so Grape doesn't JSON-serialize a placeholder.
            content_type 'application/octet-stream'
            env['api.format'] = :binary
            status :ok
            body ''
          end

          def forward_npm_candidate?(project)
            ::Security::DependencyFirewall::Availability.available?(project) &&
              project.npm_package_requests_forwarding
          end
        end
      end
    end
  end
end
