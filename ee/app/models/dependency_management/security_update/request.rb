# frozen_string_literal: true

module DependencyManagement
  module SecurityUpdate
    # Value object that wraps an Sbom::Occurrence and exposes
    # attributes needed for security update operations
    class Request
      BRANCH_PREFIX = 'dependency-management'

      attr_reader :sbom_occurrence, :vulnerability, :source_ref, :target_ref

      def initialize(sbom_occurrence:, vulnerability:, target_ref: nil)
        raise ArgumentError, 'sbom_occurrence is required' unless sbom_occurrence
        raise ArgumentError, 'vulnerability is required' unless vulnerability

        unless sbom_occurrence.project_id == vulnerability.project_id
          raise ArgumentError, 'vulnerability and sbom_occurrence must belong to the same project'
        end

        @sbom_occurrence = sbom_occurrence
        @vulnerability = vulnerability
        @target_ref = target_ref || sbom_occurrence.project.default_branch
        # Generates a deterministic branch name for the security update.
        # Format: {prefix}/{depNameSanitized}-{major}.x
        #
        # Examples:
        #   - dependency-management/rails-6.x
        #   - dependency-management/nokogiri-1.x
        @source_ref = "#{BRANCH_PREFIX}/#{dep_name_sanitized}-#{major_version}.x"
      end

      def ecosystem
        sbom_occurrence.package_manager
      end

      def filepath
        sbom_occurrence.input_file_path
      end

      def dependency
        sbom_occurrence.component_name
      end

      def current_version
        sbom_occurrence.version
      end

      # Sanitizes dependency name for use in branch names.
      # Replaces non-alphanumeric characters with hyphens and lowercases.
      def dep_name_sanitized
        dependency
          .downcase
          .gsub(/[^a-z0-9]/, '-').squeeze('-')
          .gsub(/^-|-$/, '')
      end

      # Extracts the major version from the current version.
      def major_version
        SemverDialects::SemanticVersion.new(current_version.to_s).major
      rescue SemverDialects::Error, FrozenError
        # Unparseable versions still need a branch name, so fall back to a
        # leading digit, tolerating a `v` prefix.
        current_version.to_s[/\Av?(\d+)/, 1] || '0'
      end
    end
  end
end
