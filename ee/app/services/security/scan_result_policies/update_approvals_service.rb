# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class UpdateApprovalsService
      include Gitlab::Utils::StrongMemoize
      include VulnerabilityStatesHelper
      include ::Security::ScanResultPolicies::PolicyLogger
      include ::Security::ScanResultPolicies::RelatedPipelines

      ViolationResult = Struct.new(:violated, :newly_detected, :previously_existing, keyword_init: true)

      attr_reader :pipeline, :merge_request

      def initialize(merge_request:, pipeline:)
        @pipeline = pipeline
        @merge_request = merge_request
      end

      def execute
        unless pipeline_with_security_reports_exists?
          log_update_approval_rule('No security reports found for the pipeline', **validation_context)
          return
        end

        approval_rules = merge_request.approval_rules.scan_finding
                           .including_scan_result_policy_read.including_approval_policy_rule
        approval_rules_with_newly_detected_states = filter_newly_detected_rules(:scan_finding, approval_rules)
        return if approval_rules_with_newly_detected_states.empty?

        evaluate_rules(approval_rules_with_newly_detected_states)
        evaluation.save
      end

      def scan_missing?(approval_rule)
        target_scans_missing_in_source(approval_rule).any?
      end

      private

      def pipeline_with_security_reports_exists?
        # First check if our pipeline has reports before looking up related pipelines
        return true if pipeline.can_store_security_reports?

        related_pipeline_with_security_reports_exists?
      end

      def related_pipeline_with_security_reports_exists?
        related_pipelines(pipeline).with_reports(::Ci::JobArtifact.security_reports).exists?
      end

      def validation_context(approval_rule = nil)
        if approval_rule
          { pipeline_ids: related_source_pipeline_ids, target_pipeline_ids: related_target_pipeline_ids(approval_rule) }
        else
          { pipeline_ids: related_source_pipeline_ids }
        end
      end

      delegate :project, to: :pipeline

      def evaluate_rules(approval_rules)
        log_update_approval_rule('Evaluating scan_finding rules from approval policies', **validation_context)

        approval_rules.each do |merge_request_approval_rule|
          next if enforce_scans_presence!(merge_request_approval_rule)
          next if enforce_scan_completion!(merge_request_approval_rule)
          next if enforce_scan_job_success!(merge_request_approval_rule)

          approval_rule = merge_request_approval_rule.try(:source_rule) || merge_request_approval_rule
          violation_result = violates_approval_rule?(approval_rule)

          if violation_result.violated
            log_update_approval_rule(
              'Updating MR approval rule',
              reason: 'scan_finding rule violated',
              approval_rule_id: merge_request_approval_rule.id,
              approval_rule_name: merge_request_approval_rule.name
            )
            fail_evaluation_with_data!(merge_request_approval_rule,
              newly_detected: violation_result.newly_detected,
              previously_existing: violation_result.previously_existing
            )
          else
            evaluation.pass!(merge_request_approval_rule)
          end
        end
      end

      def enforce_scans_presence!(approval_rule)
        source_scans_diff = target_scans_missing_in_source(approval_rule)
        if source_scans_diff.any?
          handle_scanner_mismatch_error(
            approval_rule, :scan_removed, 'Scanner removed by MR', source_scans_diff
          )
          return true
        end

        target_scans_diff = target_scans_missing(approval_rule)
        if target_scans_diff.any?
          # Missing target scans are logged for observability only; we do not block on them.
          # See https://gitlab.com/gitlab-org/gitlab/-/issues/577681#note_2900789165
          log_missing_target_pipeline_scans(approval_rule, target_scans_diff)
        end

        false
      end

      # Detects when security scans exist in the pipeline but did not complete successfully
      # (the job was canceled or failed after producing artifacts). This prevents a bypass
      # where canceled scans with artifacts appear "present" but produce zero ingested findings.
      #
      # When a canceled job has NO artifacts, UnenforceablePolicyRulesNotificationService
      # handles it. This method only handles the case where artifacts exist but the
      # scan did not succeed.
      def enforce_scan_completion!(approval_rule)
        scanners = approval_rule.scanners_with_default_fallback

        non_succeeded = pipeline_security_scan_types - succeeded_pipeline_security_scan_types
        non_succeeded &= scanners
        return false if non_succeeded.empty?

        handle_scanner_mismatch_error(
          approval_rule, :scan_not_succeeded,
          'Security scan did not complete successfully', non_succeeded
        )
        true
      end

      def succeeded_pipeline_security_scan_types
        Security::Scan.by_pipeline_ids(related_source_pipeline_ids).succeeded.distinct_scan_types
      end
      strong_memoize_attr :succeeded_pipeline_security_scan_types

      # Detects when a scanner required by the rule has a CI job that did not succeed and produced
      # no artifact, so no Security::Scan row exists (missed by enforce_scan_completion!). Without
      # an artifact the pipeline may still hold reports from other scanners, so
      # UnenforceablePolicyRulesNotificationService does not treat the reports as missing either.
      # We detect the failing job from its CI config (reports declaration), independent of artifacts.
      def enforce_scan_job_success!(approval_rule)
        return false unless Feature.enabled?(:approval_policies_block_on_failed_scan_job, project)

        scanners = approval_rule.scanners_with_default_fallback
        failed = failed_scan_job_types & scanners
        # Scanners that produced a Security::Scan row are handled by enforce_scan_completion!
        failed -= pipeline_security_scan_types
        return false if failed.empty?

        handle_scanner_mismatch_error(
          approval_rule, :scan_not_succeeded,
          'Security scan job did not succeed and produced no report', failed
        )
        true
      end

      # Only failed and canceled jobs are considered. Non-terminal statuses (created, pending, running)
      # would block prematurely on a scan that is still in progress, and `manual`/`skipped` jobs are a
      # deliberate configuration choice rather than a scan that ran and did not produce a verdict.
      # Canceling a job is a known approval-bypass vector, so it is treated like a failure.
      def unsuccessful_scan_jobs
        ::Ci::Build.in_pipelines(related_source_pipeline_ids)
          .latest
          .failed_or_canceled
          .with_secure_reports_from_config_options(ApprovalProjectRule::SUPPORTED_SCANNERS)
      end

      def failed_scan_job_types
        # One query answers the common case (no unsuccessful scan job at all) instead of one per scanner.
        return [] unless unsuccessful_scan_jobs.exists?

        ApprovalProjectRule::SUPPORTED_SCANNERS.select do |scan_type|
          unsuccessful_scan_jobs.with_secure_reports_from_config_options([scan_type]).exists?
        end
      end
      strong_memoize_attr :failed_scan_job_types

      def log_missing_target_pipeline_scans(approval_rule, missing_scanners)
        pipeline = target_pipeline(approval_rule)
        attributes = {
          project: merge_request.project,
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          missing_scanners: missing_scanners,
          target_pipeline_id: pipeline&.id,
          target_pipeline_status: pipeline&.status,
          source_pipeline_scans: pipeline_security_scan_types,
          target_pipeline_scans: target_pipeline_security_scan_types(approval_rule)
        }

        if pipeline && !pipeline.has_security_reports?
          # Check if we could find a pipeline with security reports if we used `time_window`.
          # We try finding a pipeline within the 1 hour window around the considered pipeline.
          pipeline_within_time_window = find_pipeline_within_time_window(
            merge_request, pipeline, 60, :scan_finding
          )
          attributes.merge!(
            pipeline_within_time_window_id: pipeline_within_time_window.id,
            pipeline_within_time_window_status: pipeline_within_time_window.status,
            pipeline_within_time_window_scans: security_scan_types(pipeline_within_time_window.id)
          )
        end

        log_policy_evaluation('approval_policy_missing_target_scan',
          'Enforced scanner missing on target branch',
          **attributes
        )
      end

      def handle_scanner_mismatch_error(approval_rule, reason, reason_msg, missing_scans)
        unless fail_open?(approval_rule)
          log_update_approval_rule(
            'Updating MR approval rule',
            reason: reason_msg,
            approval_rule_id: approval_rule.id,
            approval_rule_name: approval_rule.name,
            missing_scans: missing_scans
          )
        end

        evaluation.error!(
          approval_rule, reason, context: validation_context(approval_rule), missing_scans: missing_scans
        )
      end

      def log_update_approval_rule(message, **attributes)
        log_policy_evaluation('update_approvals', message,
          project: project, merge_request_id: merge_request.id, merge_request_iid: merge_request.iid, **attributes)
      end

      def violates_approval_rule?(approval_rule)
        return violates_grouped_scanners?(approval_rule) if approval_rule.scanner_configurations.present?

        pipeline_uuids = pipeline_findings_uuids(approval_rule)

        return ViolationResult.new(violated: false) if only_newly_detected?(approval_rule) && pipeline_uuids.empty?

        violates_vulnerabilities_allowed?(approval_rule, pipeline_uuids)
      end

      def violates_vulnerabilities_allowed?(approval_rule, pipeline_uuids)
        vulnerabilities_allowed = approval_rule.vulnerabilities_allowed
        target_pipeline_uuids = target_pipeline_findings_uuids(approval_rule)
        new_uuids = pipeline_uuids - target_pipeline_uuids

        if only_newly_detected?(approval_rule)
          violated = new_uuids.count > vulnerabilities_allowed
          return ViolationResult.new(violated: violated, newly_detected: new_uuids)
        end

        vulnerabilities_count = vulnerabilities_count_for_uuids(pipeline_uuids + target_pipeline_uuids, approval_rule)
        previously_existing_uuids = (pipeline_uuids + target_pipeline_uuids - new_uuids).uniq
        previously_existing_uuids = uuids_matching_policy_states(previously_existing_uuids, approval_rule)

        if vulnerabilities_count[:exceeded_allowed_count]
          return ViolationResult.new(
            violated: true, newly_detected: new_uuids, previously_existing: previously_existing_uuids
          )
        end

        total_count = vulnerabilities_count[:count]
        total_count += new_uuids.count if include_newly_detected?(approval_rule)

        violated = total_count > vulnerabilities_allowed
        ViolationResult.new(
          violated: violated, newly_detected: new_uuids, previously_existing: previously_existing_uuids
        )
      end

      def violates_grouped_scanners?(approval_rule)
        grouped_results = grouped_findings_evaluator(
          pipeline, approval_rule, related_source_pipeline_ids, dismissed_filter_for(approval_rule)
        ).grouped_results || []

        target_uuids = grouped_target_uuids(approval_rule)

        all_new_uuids = []
        all_previously_existing_uuids = []
        violated = false

        grouped_results.each do |group_result|
          violation_result = evaluate_group_violation(group_result, target_uuids, approval_rule)
          next unless violation_result.violated

          all_new_uuids.concat(violation_result.newly_detected)
          all_previously_existing_uuids.concat(violation_result.previously_existing || [])
          violated = true
        end

        ViolationResult.new(
          violated: violated,
          newly_detected: all_new_uuids.uniq,
          previously_existing: all_previously_existing_uuids.uniq
        )
      end

      def grouped_target_uuids(approval_rule)
        target_results = grouped_findings_evaluator(
          target_pipeline(approval_rule), approval_rule,
          related_target_pipeline_ids(approval_rule), nil
        ).grouped_results || []

        target_results.filter_map(&:uuids).flatten.uniq
      end

      def evaluate_group_violation(group_result, target_uuids, approval_rule)
        group_allowed = group_result.vulnerabilities_allowed || approval_rule.vulnerabilities_allowed
        new_uuids = (group_result.uuids || []) - target_uuids

        if only_newly_detected?(approval_rule)
          ViolationResult.new(violated: new_uuids.count > group_allowed, newly_detected: new_uuids)
        else
          evaluate_previously_existing_states(group_result, target_uuids, new_uuids, approval_rule, group_allowed)
        end
      end

      def evaluate_previously_existing_states(group_result, target_uuids, new_uuids, approval_rule, group_allowed)
        previously_existing = ((group_result.uuids || []) + target_uuids - new_uuids).uniq
        previously_existing = uuids_matching_policy_states(previously_existing, approval_rule)
        combined_uuids = (group_result.uuids || []) + target_uuids

        vulnerabilities_count = vulnerabilities_count_for_uuids(combined_uuids, approval_rule, group_allowed)

        violated = if vulnerabilities_count[:exceeded_allowed_count]
                     true
                   else
                     total = vulnerabilities_count[:count]
                     total += new_uuids.count
                     total > group_allowed
                   end

        ViolationResult.new(violated: violated, newly_detected: new_uuids, previously_existing: previously_existing)
      end

      def grouped_findings_evaluator(pipeline, approval_rule, pipeline_ids, dismissed)
        evaluator_params = {
          vulnerability_states: approval_rule.vulnerability_states_for_branch,
          severity_levels: approval_rule.severity_levels,
          vulnerabilities_allowed: approval_rule.vulnerabilities_allowed,
          scanner_configurations: approval_rule.scanner_configurations,
          dismissed: dismissed
        }

        evaluator_params[:related_pipeline_ids] = pipeline_ids if pipeline_ids.present?

        Security::ScanResultPolicies::GroupedFindingsEvaluator.new(project, pipeline, evaluator_params)
      end

      def target_scans_missing_in_source(approval_rule)
        scanners = approval_rule.scanners_with_default_fallback
        # No target pipeline, report specified scanners that are not on the source branch as missing
        return scanners - pipeline_security_scan_types unless target_pipeline(approval_rule)

        # Ensure that all target pipeline scans are also present in the source pipeline
        scan_types_diff = target_pipeline_security_scan_types(approval_rule) - pipeline_security_scan_types
        # Return the diff for specified scanners
        scan_types_diff & scanners
      end

      def target_scans_missing(approval_rule)
        scanners = approval_rule.scanners_with_default_fallback
        return scanners unless target_pipeline(approval_rule)

        target_scans = target_pipeline_security_scan_types(approval_rule)
        return scanners if target_scans.none?

        # Ensure that all source pipeline scans are also present in the target pipeline
        scan_types_diff = pipeline_security_scan_types - target_scans
        # Return the diff for specified scanners
        scan_types_diff & scanners
      end

      def pipeline_security_scan_types
        security_scan_types(related_source_pipeline_ids)
      end
      strong_memoize_attr :pipeline_security_scan_types

      def target_pipeline_security_scan_types(approval_rule)
        strong_memoize_with(:target_pipeline_security_scan_types, approval_rule) do
          security_scan_types(related_target_pipeline_ids(approval_rule))
        end
      end

      def fail_evaluation_with_data!(rule, newly_detected: nil, previously_existing: nil)
        evaluation.fail!(
          rule,
          data: {
            uuids: {
              newly_detected: Security::ScanResultPolicyViolation.trim_violations(newly_detected),
              previously_existing: Security::ScanResultPolicyViolation.trim_violations(previously_existing)
            }.compact_blank
          },
          context: validation_context(rule)
        )

        evaluation.add_violation_detail_data!(rule, {
          full_newly_detected_uuids: Array.wrap(newly_detected),
          full_previously_existing_uuids: Array.wrap(previously_existing)
        }.compact_blank)
      end

      def evaluation
        @evaluation ||= Security::SecurityOrchestrationPolicies::PolicyRuleEvaluationService.new(merge_request)
      end

      def security_scan_types(pipeline_ids)
        Security::Scan.by_pipeline_ids(pipeline_ids).distinct_scan_types
      end

      def target_pipeline(approval_rule)
        strong_memoize_with(:target_pipeline, approval_rule) do
          target_pipeline_for_merge_request(merge_request, :scan_finding, approval_rule)
        end
      end

      def related_target_pipeline_ids(approval_rule)
        strong_memoize_with(:related_target_pipeline_ids, approval_rule) do
          related_target_pipeline_ids_for_merge_request(merge_request, :scan_finding, approval_rule)
        end
      end

      def related_source_pipeline_ids
        related_pipeline_ids(pipeline)
      end
      strong_memoize_attr :related_source_pipeline_ids

      def target_pipeline_findings_uuids(approval_rule)
        findings_uuids(target_pipeline(approval_rule), approval_rule, related_target_pipeline_ids(approval_rule))
      end

      def pipeline_findings_uuids(approval_rule)
        findings_uuids(pipeline, approval_rule, related_source_pipeline_ids,
          dismissed_filter_for(approval_rule))
      end

      def findings_uuids(pipeline, approval_rule, pipeline_ids, dismissed = nil)
        finder_params = {
          severity_levels: approval_rule.severity_levels,
          scanners: approval_rule.scanners,
          fix_available: approval_rule.vulnerability_attribute_fix_available,
          false_positive: approval_rule.vulnerability_attribute_false_positive,
          known_exploited: approval_rule.vulnerability_attribute_known_exploited,
          epss_score: approval_rule.vulnerability_attribute_epss_score,
          enrichment_data_unavailable_action: approval_rule.vulnerability_attribute_enrichment_data_unavailable_action,
          dismissed: dismissed
        }

        finder_params[:related_pipeline_ids] = pipeline_ids if pipeline_ids.present?

        Security::ScanResultPolicies::FindingsFinder
          .new(project, pipeline, finder_params)
          .execute
          .distinct_context_unaware_uuids
      end

      def dismissed_filter_for(approval_rule)
        states = approval_rule.vulnerability_states_for_branch
        has_needs_triage = states.include?(ApprovalProjectRule::NEW_NEEDS_TRIAGE)
        has_dismissed = states.include?(ApprovalProjectRule::NEW_DISMISSED)

        if has_needs_triage && !has_dismissed
          false
        elsif has_dismissed && !has_needs_triage
          true
        end
      end

      def vulnerabilities_count_for_uuids(uuids, approval_rule, allowed_count = approval_rule.vulnerabilities_allowed)
        VulnerabilitiesCountService.new(
          project: project,
          uuids: uuids,
          states: states_without_newly_detected(approval_rule.vulnerability_states_for_branch),
          allowed_count: allowed_count,
          vulnerability_age: approval_rule.approval_policy_source&.vulnerability_age
        ).execute
      end

      # Filters UUIDs to only those with a vulnerability in the policy's tracked
      # pre-existing states. Aligns the stored violation data with
      # VulnerabilitiesCountService, which uses the same vulnerability_reads
      # query for counting. Without this, vulnerabilities in non-tracked states
      # (e.g. dismissed, resolved) leak into violation data from the target
      # pipeline and appear in the bot comment.
      def uuids_matching_policy_states(uuids, approval_rule)
        return uuids if uuids.blank?

        states = states_without_newly_detected(approval_rule.vulnerability_states_for_branch)
        return uuids if states.blank?

        project.vulnerability_reads.by_uuid(uuids).with_states(states).fetch_uuids
      end

      def fail_open?(approval_rule)
        approval_rule.approval_policy_source&.fail_open?
      end
    end
  end
end
