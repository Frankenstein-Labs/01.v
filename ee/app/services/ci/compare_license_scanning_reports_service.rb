# frozen_string_literal: true

module Ci
  class CompareLicenseScanningReportsService < ::Ci::CompareReportsBaseService
    include ::Gitlab::Utils::StrongMemoize

    def comparer_class
      Gitlab::Ci::Reports::LicenseScanning::ReportsComparer
    end

    def serializer_class
      ::LicenseCompliance::ComparerSerializer
    end

    def get_report(pipeline)
      ::SCA::LicenseCompliance.new(pipeline&.project || project, pipeline, merge_request&.target_branch)
    end

    private

    attr_reader :comparer_entity

    def merge_request
      project.merge_requests.find_by_id(params[:id])
    end
    strong_memoize_attr :merge_request

    def build_comparer(base_report, head_report)
      @comparer_entity = comparer_class.new(base_report, head_report)
    end

    def approval_required
      return false unless params[:id]

      return false unless merge_request

      (merge_request.approval_rules.license_compliance.any? ||
        merge_request.approval_rules.scan_finding.any?) && has_denied_licenses?
    end
    strong_memoize_attr :approval_required

    def has_denied_licenses?
      licenses = comparer_entity.new_licenses

      return false if licenses.nil? || licenses.empty?

      licenses.any? do |l|
        l.approval_status == 'denied'
      end
    end
    strong_memoize_attr :has_denied_licenses?

    def serializer_params
      {
        project: project,
        current_user: current_user,
        approval_required: approval_required,
        has_denied_licenses: has_denied_licenses?
      }
    end

    def key(base_pipeline, head_pipeline)
      super(base_pipeline, head_pipeline) + [project.software_license_policies.cache_key]
    end
  end
end
