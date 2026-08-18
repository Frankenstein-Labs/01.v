# frozen_string_literal: true

module Vulnerabilities
  class CompareSecurityReportsService < ::Ci::CompareReportsBaseService
    def build_comparer(base_report, head_report)
      comparison_params = params.merge(
        base_report: base_report,
        head_report: head_report,
        partial_scan_scanner_ids: partial_scan_scanner_ids
      )
      comparer_class.new(project, comparison_params)
    end

    # For full scan comparisons where the head pipeline includes partial scans,
    # identify the scanners configured for partial scanning and filter out their
    # findings from the base pipeline. This prevents vulnerabilities detected by
    # those scanners in the base pipeline from incorrectly appearing as "fixed"
    # in the full scan tab, since they're already handled in the partial scan comparison.
    def partial_scan_scanner_ids
      return [] unless params[:scan_mode] == 'full'
      return [] if head_pipeline.nil?

      partial_scans = head_pipeline.security_scans.partial.to_a
      return Set.new if partial_scans.empty?

      build_type_pairs = partial_scans.map do |scan|
        file_type_value = ::Ci::JobArtifact.file_types[scan.scan_type]
        [scan.build_id, file_type_value]
      end

      artifacts = head_pipeline.job_artifacts
                               .security_reports_by_build_and_type_pairs(build_type_pairs)

      artifacts.filter_map do |artifact|
        artifact&.security_report&.scanner&.external_id
      end.to_set
    end

    def comparer_class
      Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer
    end

    def serializer_class
      Vulnerabilities::FindingDiffSerializer
    end

    def get_report(pipeline)
      return :parsing unless security_findings_stored?(pipeline)

      findings = Security::FindingsFinder.new(
        pipeline,
        params: {
          report_type: params[:report_type],
          scope: 'all',
          scan_mode: scan_mode_for_pipeline(pipeline),
          limit: max_findings_count
        }
      ).execute.with_api_scopes

      findings_array = findings.to_a
      Security::Finding.preload_auto_dismissal_checks!(project, findings_array)
      Security::Finding.preload_severity_override_checks!(project, findings_array)

      Gitlab::Ci::Reports::Security::AggregatedFinding.new(pipeline, findings_array)
    end

    def execute(base_pipeline, head_pipeline)
      @base_pipeline = base_pipeline
      @head_pipeline = head_pipeline
      super
    end

    private

    attr_reader :base_pipeline, :head_pipeline

    def max_findings_count
      if Feature.enabled?(:security_mr_reports_tab_full_data_set, project)
        Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer::MAX_FULL_DATA_SET_FINDINGS
      else
        Gitlab::Ci::Reports::Security::SecurityFindingsReportsComparer::MAX_FINDINGS_COUNT
      end
    end

    def scan_mode_for_pipeline(pipeline)
      # For partial scan comparisons, we want to compare full scan results from the base pipeline
      # against partial scan results from the head pipeline. This prevents existing vulnerabilities
      # from appearing as "new" when they're detected by partial scans on feature branches.
      if params[:scan_mode] == 'partial' && pipeline == base_pipeline
        'full'
      else
        params[:scan_mode]
      end
    end

    def security_findings_stored?(pipeline)
      return true if pipeline.nil?

      Security::Scan.results_ready?(pipeline, params[:report_type])
    end
  end
end
