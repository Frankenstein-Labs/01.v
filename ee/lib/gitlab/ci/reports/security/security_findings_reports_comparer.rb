# frozen_string_literal: true

module Gitlab
  module Ci
    module Reports
      module Security
        class SecurityFindingsReportsComparer
          include Gitlab::Utils::StrongMemoize

          attr_reader :project, :params, :added_findings, :fixed_findings

          ACCEPTABLE_REPORT_AGE = 1.week
          MAX_FINDINGS_COUNT = 25
          MAX_FULL_DATA_SET_FINDINGS = 1_000
          VULNERABILITY_FILTER_METRIC_KEY = :vulnerability_report_branch_comparison

          def initialize(project, params)
            @project = project
            @params = params

            @added_findings = []
            @fixed_findings = []
            calculate_changes
          end

          def base_report
            params[:base_report]
          end

          def head_report
            params[:head_report]
          end

          def base_report_created_at
            base_report.created_at
          end

          def head_report_created_at
            head_report.created_at
          end

          def base_report_out_of_date
            return false unless base_report.created_at

            base_report.created_at.before?(ACCEPTABLE_REPORT_AGE.ago)
          end

          # rubocop:disable CodeReuse/ActiveRecord -- pluck method requires this
          def undismissed_on_default_branch(findings, limit)
            uuids = findings.map(&:uuid)

            query = Vulnerability
              .present_on_default_branch.with_findings_by_uuid_and_state(uuids, :dismissed)
              .limit(limit)

            dismissed_uuids = ::Gitlab::Metrics.measure(VULNERABILITY_FILTER_METRIC_KEY) do
              query.pluck('findings.uuid')
            end.to_set

            findings.reject { |f| dismissed_uuids.include?(f.uuid) }
          end

          def process_findings(findings)
            if Feature.enabled?(:security_mr_reports_tab_full_data_set, project)
              return findings.each_slice(MAX_FINDINGS_COUNT).flat_map do |slice|
                undismissed_on_default_branch(slice, slice.size)
              end
            end

            unchecked_findings = findings.each_slice(MAX_FINDINGS_COUNT).to_a
            undismissed_findings = []
            limit = MAX_FINDINGS_COUNT

            while unchecked_findings.any? && limit > 0
              undismissed_findings += undismissed_on_default_branch(unchecked_findings.shift, limit)
              limit -= undismissed_findings.size
            end

            undismissed_findings
          end
          # rubocop:enable CodeReuse/ActiveRecord

          def added
            process_findings(added_findings)
          end
          strong_memoize_attr :added

          def fixed
            process_findings(fixed_findings)
          end
          strong_memoize_attr :fixed

          def errors
            []
          end
          strong_memoize_attr :errors

          def warnings
            []
          end
          strong_memoize_attr :warnings

          private

          def calculate_changes
            base_findings = base_report.findings
            head_findings = head_report.findings

            # For full scan comparisons where the head pipeline includes partial scans,
            # filter out base findings from scanners that also run as partial scans
            # (identified by partial_scan_scanner_ids). This prevents vulnerabilities
            # detected by those scanners in the base pipeline from incorrectly appearing
            # as "fixed" in the full scan tab, since they're already handled in their
            # respective partial scan comparisons.
            if params[:scan_mode] == 'full' && params[:partial_scan_scanner_ids].present?
              base_findings = base_findings.reject do |finding|
                params[:partial_scan_scanner_ids].include?(finding.scanner.external_id)
              end
            end

            base_findings_uuids_set = base_findings.map(&:policy_comparison_uuid).to_set
            head_findings_uuids_set = head_findings.map(&:policy_comparison_uuid).to_set

            @added_findings = head_findings.reject { |f| base_findings_uuids_set.include?(f.policy_comparison_uuid) }

            # Partial scans only have coverage of changed files are
            # unlikely to find all existing vulnerabilities.
            # We hide the fixed results since they will often be wrong.
            return if params[:scan_mode] == 'partial'

            @fixed_findings = base_findings.reject do |finding|
              finding.requires_manual_resolution? || head_findings_uuids_set.include?(finding.policy_comparison_uuid)
            end
          end
        end
      end
    end
  end
end
