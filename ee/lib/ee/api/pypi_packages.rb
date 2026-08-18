# frozen_string_literal: true

module EE
  module API
    module PypiPackages
      extend ActiveSupport::Concern

      # Matches the timeout the deleted Ruby upstream client passed to Gitlab::HTTP.
      UPSTREAM_TIMEOUT_SECONDS = 10

      prepended do
        helpers ::EE::API::Helpers::DependencyFirewallHelpers

        helpers do
          extend ::Gitlab::Utils::Override

          # Name is PEP 503-normalized so policy rules match regardless of how the
          # package was published; the `package&.project` guard is defensive (the
          # finder raises before this runs).
          override :enforce_dependency_firewall_on_download!
          def enforce_dependency_firewall_on_download!(package)
            return unless package&.project
            return unless ::Security::DependencyFirewall::Availability.feature_flag_enabled?(package.project)

            enforce_dependency_firewall!(
              project: package.project,
              pkg_type: 'pypi',
              name: package.normalized_pypi_name,
              version: package.version,
              operation: ::Security::DependencyFirewall::EnforcementService::PACKAGE_DOWNLOAD
            )
          end

          # No package record exists yet, so the raw upload name is normalized via the
          # shared Sbom::PackageUrl::Normalizer (PEP 503 for pypi), matching the read
          # path's Packages::Pypi::Package#normalized_pypi_name.
          override :enforce_dependency_firewall_on_upload!
          def enforce_dependency_firewall_on_upload!(project, name, version)
            return if name.blank? || version.blank?
            return unless ::Security::DependencyFirewall::Availability.feature_flag_enabled?(project)

            enforce_dependency_firewall!(
              project: project,
              pkg_type: 'pypi',
              name: ::Sbom::PackageUrl::Normalizer.new(type: 'pypi', text: name).normalize_name,
              version: version,
              operation: ::Security::DependencyFirewall::EnforcementService::PACKAGE_UPLOAD
            )
          end

          # Fills the CE forward route. Rebuilds the upstream URL from the client path,
          # whose first segment is the upstream host the metadata rewrite encoded there,
          # and 302s. The redirect is gated on the forwarding setting alone
          # (DFW-independent), so GitLab `forward` URLs baked into pip/poetry lockfiles
          # keep resolving after a DFW license/flag lapse. The firewall is layered only
          # when DFW is licensed + enabled (matching the metadata
          # `forward_pypi_simple_candidate?` gate); under DFW an unparseable version
          # fails closed (404) rather than forwarding an unenforceable download, as does
          # a path that isn't a plain artifact path on an allowed host.
          # `.metadata` (PEP 658) is stripped before version derivation.
          override :handle_pypi_forwarded_download!
          def handle_pypi_forwarded_download!(project, package_name, upstream_path)
            return false unless redirect_registry_request_available?(:pypi, project)

            # Validated up front so the URL we 302 to and the filename we derive the
            # enforced version from are the same trusted value.
            upstream_url = ::Packages::Pypi::Upstream::Configuration.file_url_for(upstream_path)
            return false if upstream_url.nil?

            # PEP 658 now reaches pip, so it fetches `<file>.metadata` before the
            # artifact and both land here. The metadata request is still firewalled,
            # but it is not a package pull: counting it would inflate forwarded pulls
            # against locally hosted ones and record a pull for a resolve that never
            # downloads anything.
            metadata_request = upstream_path.end_with?('.metadata')

            if forward_pypi_simple_candidate?(project)
              coordinates = ::Packages::Pypi::Upstream::Configuration
                .enforced_coordinates(upstream_path, claimed_name: package_name)
              return false unless coordinates

              name, version = coordinates

              enforce_dependency_firewall!(
                project: project,
                pkg_type: 'pypi',
                name: name,
                version: version,
                operation: ::Security::DependencyFirewall::EnforcementService::PACKAGE_DOWNLOAD
              )
            end

            unless metadata_request
              track_package_event('pull_package', :pypi, project: project, namespace: project.namespace)
            end

            redirect(upstream_url)

            true
          end

          override :present_simple_package
          def present_simple_package(group_or_project)
            return super unless forward_pypi_simple_candidate?(group_or_project)

            authorize_read_package!(group_or_project)

            return super unless package_missing_locally?(group_or_project)

            # Preserve the forwarding metric the CE `redirect_registry_request` path
            # emits, since the Workhorse hand-off replaces that redirect. Without it a
            # project's pypi forwarding volume reads zero once the flag is on.
            ::Gitlab::Tracking.event(options[:for].name, 'pypi_request_forward')

            track_simple_event(group_or_project, 'list_package')

            json = pep_691_json_enabled?(group_or_project) && json_format_requested?
            # Escaped: normalization leaves `?`/`#`/spaces in place, and this lands in
            # the prefix every rewritten file URL is built from.
            escaped_name = ::Packages::Pypi::Upstream::Configuration.escaped_name(params[:package_name])

            header(*::Gitlab::Workhorse.send_url(
              registry_url(:pypi, package_name: escaped_name),
              # Force the upstream Accept to match our transform choice so the
              # streamed body format and the transform never disagree.
              headers: { 'Accept' => json ? ::API::PypiPackages::PEP_691_JSON_CONTENT_TYPE : 'text/html' },
              ssrf_filter: true,
              allow_localhost: Rails.env.development?,
              # Carried over from the Ruby client this replaces, which passed a
              # 10s timeout to Gitlab::HTTP. Without them Workhorse falls back to
              # its own defaults -- no dial timeout at all, and 30s for response
              # headers -- so a slow upstream would hold the connection far longer
              # than it used to.
              #
              # These bound the connect and the wait for response headers, not the
              # body: nothing aborts an upstream that answers quickly and then
              # dribbles. Adding an idle-read timeout is tracked in
              # https://gitlab.com/gitlab-org/gitlab/-/work_items/609164.
              timeouts: { open: UPSTREAM_TIMEOUT_SECONDS, read: UPSTREAM_TIMEOUT_SECONDS },
              response_statuses: { error: :bad_gateway, timeout: :bad_gateway },
              restrict_forwarded_response_headers: { enabled: true, allow_list: %w[Content-Type ETag] },
              # Matching the scheme rather than the CDN host captures every file URL,
              # so the upstream host survives as the first segment of the forward path
              # and an off-CDN entry is rejected at download time instead of being
              # handed to pip unrewritten. Workhorse also matches the http spelling,
              # and neither scheme is carried through -- see Configuration::URL_SCHEME.
              transform_config: {
                format: json ? :json : :html,
                key: json ? 'url' : 'href',
                from: ::Packages::Pypi::Upstream::Configuration::URL_SCHEME,
                to: forward_route_prefix(group_or_project, escaped_name)
              }
            ))

            header 'Vary', 'Accept'

            # The upstream Content-Type is allow-listed through, so a browser would
            # otherwise render pypi.org's document at a gitlab.example.com URL, and
            # the transform copies `<script>`/`<iframe>`/`<form>` through verbatim
            # where the presenter this replaces rebuilt the page from escaped
            # fields. The default CSP already blocks inline script; this stops the
            # document being treated as same-origin markup at all. pip ignores it.
            header 'Content-Disposition', 'attachment'

            # Workhorse produces the real response from the send-url instruction;
            # emit an empty binary body so Grape doesn't serialize a placeholder.
            content_type 'application/octet-stream'
            env['api.format'] = :binary
            status :ok
            body ''
          end

          private

          # The prefix every rewritten file URL is built from. Derived from the route
          # rather than hardcoded so it follows the route definition, and given a
          # trailing slash because the transform concatenates the upstream host and
          # path onto it -- without one the two would run together.
          #
          # `escaped_name` is already percent-encoded and the helper does not escape
          # its segments, so this does not double-encode.
          def forward_route_prefix(project, escaped_name)
            path = api_v4_projects_packages_pypi_forward_upstream_path_path(
              { id: project.id, package_name: escaped_name, upstream_path: '' }, true
            )

            expose_url("#{path}/")
          end

          def forward_pypi_simple_candidate?(group_or_project)
            group_or_project.is_a?(::Project) &&
              ::Security::DependencyFirewall::Availability.available?(group_or_project) &&
              redirect_registry_request_available?(:pypi, group_or_project)
          end

          def package_missing_locally?(group_or_project)
            ::Packages::Pypi::PackagesFinder
              .new(current_user, group_or_project, { package_name: params[:package_name] })
              .execute
              .empty?
          end
        end
      end
    end
  end
end
