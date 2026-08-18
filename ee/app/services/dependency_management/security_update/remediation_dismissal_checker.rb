# frozen_string_literal: true

module DependencyManagement
  module SecurityUpdate
    # Decides whether a proposed remediation should be skipped because a maintainer already
    # closed an MR for the same vulnerability and we would not be proposing a newer version.
    class RemediationDismissalChecker
      include Gitlab::Utils::StrongMemoize

      # @param project [Project]
      # @param vulnerability [Vulnerability] the vulnerability being remediated
      def initialize(project:, vulnerability:)
        @project = project
        @vulnerability = vulnerability
      end

      # @param output [OutputParser::Result] the orchestrator output for the current attempt
      # @return [Boolean]
      def dismissed?(output)
        return false if dismissed_versions.empty?

        output.dependencies.all? do |dependency|
          dismissed_version = dismissed_versions[dependency.name]
          dismissed_version.present? && !version_greater?(dependency.version, dismissed_version)
        end
      end

      private

      attr_reader :project, :vulnerability

      # { dependency_name => highest version the maintainer dismissed }, from MR titles.
      def dismissed_versions
        dismissed_merge_requests.each_with_object({}) do |merge_request, versions|
          match = MergeRequestTitle.parse_single_dependency(merge_request.title)
          next unless match

          name = match[:name]
          version = match[:version]
          versions[name] = version if versions[name].nil? || version_greater?(version, versions[name])
        end
      end
      strong_memoize_attr :dismissed_versions

      def dismissed_merge_requests
        UserClosedRemediationsFinder
          .new(project: project)
          .for_vulnerability(vulnerability)
          .select { |mr| mr.source_branch.start_with?("#{Request::BRANCH_PREFIX}/") }
      end
      strong_memoize_attr :dismissed_merge_requests

      def version_greater?(candidate, other)
        compare_versions(candidate, other) > 0
      end

      def compare_versions(candidate, other)
        if package_type.blank?
          log_version_comparison_failure(candidate, other, 'missing package type')
          return 1
        end

        candidate_version = SemverDialects.parse_version(package_type, candidate)
        other_version = SemverDialects.parse_version(package_type, other)
        result = candidate_version <=> other_version

        return result unless result.nil?

        log_version_comparison_failure(candidate, other, 'versions not comparable')
        1
      rescue SemverDialects::Error => error
        log_version_comparison_failure(candidate, other, error.message)
        1
      end

      def log_version_comparison_failure(candidate, other, reason)
        Gitlab::AppLogger.error(
          message: 'DependencyManagement: failed to compare versions for remediation dismissal',
          project_id: project.id,
          package_type: package_type,
          candidate_version: candidate,
          dismissed_version: other,
          error: reason
        )
      end

      def package_type
        ::Enums::Sbom.semver_dialects_purl_type(purl_type)
      end

      def purl_type
        vulnerability.sbom_occurrences.first&.purl_type
      end
      strong_memoize_attr :purl_type
    end
  end
end
