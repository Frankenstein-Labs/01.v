# frozen_string_literal: true

module DependencyManagement
  module SecurityUpdate
    class SchedulerService < BaseService
      include Gitlab::Utils::StrongMemoize
      include Gitlab::InternalEventsTracking
      include Gitlab::Loggable

      # Auto Remediation is only supported for a limited set of package managers.
      SUPPORTED_PACKAGE_MANAGERS = Eligibility::SUPPORTED_PACKAGE_MANAGERS

      # These MUST stay sorted, so that we don't have to sort using Postgres.
      # Doing so is expensive, and we cannot add another index on the sbom_occurrences
      # table.
      SORTED_SEVERITY_LEVELS = %i[critical high medium low].freeze

      private_constant :SUPPORTED_PACKAGE_MANAGERS,
        :SORTED_SEVERITY_LEVELS

      def self.execute(...)
        new(...).execute
      end

      def initialize(project:, skip_dismissed_branches: false)
        super(project: project)

        @skip_dismissed_branches = skip_dismissed_branches
        @remediation_count = open_remediations.size
      end

      def execute
        return unless project && remediation_profile

        refresh_open_remediations!

        SUPPORTED_PACKAGE_MANAGERS.each do |package_manager|
          break if merge_request_limit_reached?

          execute_for_package_manager(package_manager)
        end
      end

      private

      attr_accessor :remediation_count
      attr_reader :skip_dismissed_branches

      # Open remediation MRs keyed by source branch, fetched once. The branch set decides
      # which occurrences are already covered by an open MR, and the records themselves are
      # refreshed directly in refresh_open_remediations! Bounded by open_merge_requests_limit,
      # so a handful of rows - cheaper than re-querying per branch during the scan.
      def open_remediations
        return {} unless project

        DependencyManagement::SecurityUpdate::OpenRemediationsFinder
          .new(project: project)
          .execute
          .index_by(&:source_branch)
      end
      strong_memoize_attr :open_remediations

      def user_closed_remediations_finder
        DependencyManagement::SecurityUpdate::UserClosedRemediationsFinder.new(project: project)
      end
      strong_memoize_attr :user_closed_remediations_finder

      def execute_for_package_manager(package_manager)
        severity_levels.each do |severity_level|
          break if merge_request_limit_reached?

          execute_for_package_manager_and_severity_level(package_manager, severity_level)
        end
      end

      def execute_for_package_manager_and_severity_level(package_manager, severity_level)
        finder = DependencyManagement::SecurityUpdate::VulnerableSbomOccurrencesFinder.new(
          project: project,
          package_manager: package_manager,
          severity_level: severity_level
        )

        finder.execute_in_batches do |occurrences|
          occurrences.each do |occurrence|
            break if merge_request_limit_reached?

            schedule_remediation(occurrence)
          end
        end
      end

      def merge_request_limit_reached?
        # WARNING: We should be careful here. If this limit is ever configured,
        # we can end up in a situation where we have more merge requests
        # open than the limit. If that happens and we do a strict check
        # then we'll continue to open merge requests. This limit will
        # be configurable by the customer, so we need to take this into account.
        remediation_count >= max_open_merge_request_limit
      end

      def remediation_profile
        Eligibility.remediation_profile(project)
      end
      strong_memoize_attr :remediation_profile

      def auto_remediation_configuration
        Eligibility.remediation_configuration(project, profile: remediation_profile).fetch(:auto_remediation, {})
      end
      strong_memoize_attr :auto_remediation_configuration

      def max_open_merge_request_limit
        auto_remediation_configuration[:open_merge_requests_limit]
      end
      strong_memoize_attr :max_open_merge_request_limit

      def severity_levels
        threshold_index = SORTED_SEVERITY_LEVELS.index(severity_threshold)

        return SORTED_SEVERITY_LEVELS unless threshold_index

        SORTED_SEVERITY_LEVELS.first(threshold_index + 1)
      end
      strong_memoize_attr :severity_levels

      def severity_threshold
        auto_remediation_configuration[:severity_level].to_sym
      end

      # Schedules one update workload if there's at least one remediable vulnerability on
      # the occurrence. Each occurrence gets its own pipeline and MR so a vulnerability is
      # individually linked, tracked, and resolved.
      def schedule_remediation(sbom_occurrence)
        vulnerability = sbom_occurrence.vulnerabilities
          .sort_by { |v| [-Vulnerability.severities[v.severity], v.id] }
          .find { |v| Eligibility.remediable?(v) }

        return unless vulnerability

        request = Request.new(sbom_occurrence:, vulnerability:)

        # A branch with an open MR is refreshed up front by refresh_open_remediations!,
        # not re-created here.
        return if open_remediations.key?(request.source_ref)

        # On a reschedule run (after a dismissed update freed a slot), don't re-pick a
        # branch a maintainer already closed - hand the slot to the next fresh candidate.
        # Initial runs still re-evaluate it so a newer version can resurface.
        return if skip_dismissed_branches && user_closed_remediations_finder.dismissed_branch?(request.source_ref)

        response = UpdateService.new(project:).execute(request)

        return unless response.success?

        self.remediation_count += 1

        track_internal_event(
          "trigger_dependency_management_auto_remediation_request",
          project: project,
          additional_properties: {
            purl_type: sbom_occurrence.component.purl_type
          }
        )
      end

      # Refreshes each currently open remediation MR directly via its linked vulnerability,
      # rather than waiting to encounter it again during the occurrence scan below. A branch's
      # vulnerability can be dismissed, resolved, or fall outside the current severity/package
      # manager configuration without ever reappearing in that scan, which would otherwise
      # leave the scan unable to stop early even after the open MR limit is reached.
      def refresh_open_remediations!
        open_remediations.each_value do |merge_request|
          request = refresh_request_for(merge_request)
          next unless request

          next unless refresh_open_remediation?(merge_request)

          response = UpdateService.new(project:).execute(request)
          next if response.success?

          Gitlab::AppLogger.error(
            build_structured_payload_labkit(
              message: 'DependencyManagement: failed to refresh an auto-remediation merge request',
              project_id: project.id,
              merge_request_iid: merge_request.iid,
              source_branch: merge_request.source_branch,
              reason: response.message
            )
          )
        end
      end

      # @return [DependencyManagement::SecurityUpdate::Request, nil] a request built from the
      # merge request's linked vulnerability and its current sbom occurrence in this project,
      # or nil when the vulnerability is no longer active or no longer has a fix available.
      def refresh_request_for(merge_request)
        # max_by rather than last: the links are preloaded, so relation ordering no longer
        # applies and the most recent link has to be picked explicitly.
        vulnerability = merge_request.vulnerability_merge_request_links.max_by(&:id)&.vulnerability
        return unless vulnerability
        return unless vulnerability.detected? || vulnerability.confirmed?
        return unless Eligibility.remediable?(vulnerability)

        sbom_occurrence = vulnerability.sbom_occurrences.first
        return unless sbom_occurrence

        Request.new(sbom_occurrence:, vulnerability:)
      end

      # An open MR is normally left alone: resetting its branch on every pipeline would
      # run a workload each time. Two cases still warrant a re-run.
      #
      # @return [Boolean] true when the open remediation MR should be refreshed rather than
      # skipped.
      def refresh_open_remediation?(merge_request)
        # Re-resolve once the cooldown has elapsed, so a newer patched version
        # (e.g. 5.6.0 -> 5.6.2) reaches the open MR without a workload per pipeline.
        # Checked first: the conflict state cannot change the answer when a refresh is
        # already due, and reading it is the more expensive of the two.
        return true if RefreshCooldown.elapsed?(merge_request)

        # Nothing else will ever bring a conflicted MR back to a mergeable state: raw
        # branch writes bypass the push-triggered mergeability recheck and there's no
        # periodic sweep for it. Not cooldown-gated - it's stuck until we refresh it.
        conflicted_remediation?(merge_request)
      end

      # @return [Boolean] true when the merge request is confirmed conflicted with its
      # target branch.
      #
      # Deliberately narrow: both branches must still exist. A missing branch is a
      # different failure mode (e.g. deleted out-of-band) that this refresh path isn't
      # meant to paper over.
      #
      # Reads the recorded state rather than recomputing it: recomputing takes a
      # per-merge-request lease and hits Gitaly, and a stale answer only delays a refresh.
      def conflicted_remediation?(merge_request)
        return false unless merge_request.source_branch_exists? && merge_request.target_branch_exists?

        # GitLab records "nothing to merge" as the same unmergeable state as a real conflict,
        # so a branch still sitting at its target would be refreshed on every scheduler run.
        return false if merge_request.source_branch_sha == merge_request.target_branch_sha

        conflict_check = ::MergeRequests::Mergeability::CheckConflictStatusService
          .new(merge_request: merge_request, params: {})
          .execute

        if conflict_check.checking?
          merge_request.check_mergeability(async: true)

          return false
        end

        return false unless conflict_check.failed?

        Gitlab::AppLogger.info(
          build_structured_payload_labkit(
            message: 'DependencyManagement: refreshing a conflicted auto-remediation merge request',
            project_id: project.id,
            merge_request_iid: merge_request.iid,
            source_branch: merge_request.source_branch
          )
        )

        true
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e, project_id: project.id, source_branch: merge_request.source_branch)
        false
      end
    end
  end
end
