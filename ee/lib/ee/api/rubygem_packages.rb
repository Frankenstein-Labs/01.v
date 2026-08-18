# frozen_string_literal: true

module EE
  module API
    module RubygemPackages
      extend ActiveSupport::Concern

      prepended do
        helpers ::EE::API::Helpers::DependencyFirewallHelpers

        helpers do
          extend ::Gitlab::Utils::Override

          override :enforce_dependency_firewall_on_upload!
          def enforce_dependency_firewall_on_upload!
            return unless ::Security::DependencyFirewall::Availability.feature_flag_enabled?(project)

            spec = gem_spec_from_metadata(params[:file].path)
            return unless spec

            enforce_dependency_firewall!(
              project: project,
              pkg_type: 'gem',
              name: spec.name,
              version: spec.version.to_s,
              operation: ::Security::DependencyFirewall::EnforcementService::PACKAGE_UPLOAD
            )
          end

          override :enforce_dependency_firewall_on_download!
          def enforce_dependency_firewall_on_download!(package)
            return unless ::Security::DependencyFirewall::Availability.feature_flag_enabled?(package.project)

            enforce_dependency_firewall!(
              project: package.project,
              pkg_type: 'gem',
              name: package.name,
              version: package.version,
              operation: ::Security::DependencyFirewall::EnforcementService::PACKAGE_DOWNLOAD
            )
          end

          # Returns the gem's Gem::Specification by reading only metadata.gz, skipping the full
          # data.tar.gz gunzip that Gem::Package#spec does. metadata.gz is the first entry in a
          # rubygems-built gem, so we scan only the first few tar entries. This bounds the
          # request-thread work for a gem that places metadata.gz late or omits it entirely. The
          # upload itself does not depend on this metadata; anything that isn't a parseable gem
          # (metadata absent from the scanned entries, wrong entry type, corrupt gzip, invalid
          # YAML) returns nil and the caller skips enforcement rather than failing the upload.
          def gem_spec_from_metadata(file_path)
            max_metadata_size = 10.megabytes
            max_entries_scanned = 5

            File.open(file_path, 'rb') do |io|
              scanned = 0

              Gem::Package::TarReader.new(io).each do |entry|
                break if (scanned += 1) > max_entries_scanned
                next unless entry.full_name == 'metadata.gz' && entry.file?

                yaml = ::Zlib::GzipReader.wrap(entry, external_encoding: Encoding::UTF_8) do |gz|
                  gz.read(max_metadata_size + 1)
                end
                break if yaml.nil? || yaml.bytesize > max_metadata_size

                break Gem::Specification.from_yaml(yaml)
              end
            end
          rescue StandardError => e
            ::Gitlab::ErrorTracking.log_exception(e, package_file_path: file_path)
            nil
          end
        end
      end
    end
  end
end
