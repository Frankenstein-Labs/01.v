# frozen_string_literal: true

module Security
  module ScanResultPolicies
    # Re-evaluates pre-existing vulnerability state approval rules for every open
    # merge request in a project. Enqueued when a vulnerability is triaged
    # (dismissed / resolved / etc.), because pre-existing-state rules are scoped to
    # the project's vulnerabilities rather than to a single pipeline or merge request,
    # so the affected merge requests cannot be resolved from the triaged record alone.
    #
    # Deduplicated on project_id so a burst of triage actions collapses into a single
    # sweep. The per-merge-request worker it fans out to filters out newly-detected-only
    # rules and is itself idempotent.
    #
    # See https://gitlab.com/gitlab-org/gitlab/-/issues/560563
    class SyncProjectPreexistingStatesApprovalRulesWorker
      include ApplicationWorker

      idempotent!
      deduplicate :until_executing, including_scheduled: true
      data_consistency :delayed
      concurrency_limit -> { 200 }

      queue_namespace :security_scans
      feature_category :security_policy_management

      # Only scan_finding rules depend on vulnerability state; license_scanning rules
      # are unaffected by vulnerability triage, so they are intentionally excluded.
      REPORT_TYPES = [:scan_finding].freeze

      def perform(project_id)
        project = Project.find_by_id(project_id)
        return unless project
        # Cheap, indexed guard: skip projects that have no approval policy, so a triage
        # in a project without policies does not scan its open merge requests.
        return unless project.approval_policies.exists?

        project.merge_requests.opened.with_approval_rules_by_report_types(REPORT_TYPES).each_batch do |batch|
          batch.each do |merge_request|
            Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker.perform_async(merge_request.id)
          end
        end
      end
    end
  end
end
