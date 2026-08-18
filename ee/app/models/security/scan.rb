# frozen_string_literal: true

module Security
  class Scan < ::SecApplicationRecord
    include Ci::Partitionable::AssociationFinder
    include CreatedAtFilterable

    self.table_name = 'security_scans'

    validates :build_id, presence: true
    validates :scan_type, presence: true
    validates :info, json_schema: { filename: 'security_scan_info' }

    belongs_to :build, class_name: 'Ci::Build'
    belongs_to :project
    belongs_to :pipeline, class_name: 'Ci::Pipeline'
    partitionable_belongs_to_loader :pipeline

    has_many :findings, inverse_of: :scan
    has_one :partial_scan, class_name: 'Vulnerabilities::PartialScan'

    enum :scan_type, {
      sast: 1,
      dependency_scanning: 2,
      container_scanning: 3,
      dast: 4,
      secret_detection: 5,
      coverage_fuzzing: 6,
      api_fuzzing: 7,
      cluster_image_scanning: 8,
      sarif: 9
    }

    declarative_enum Security::ScanStatusEnum

    scope :by_scan_types, ->(scan_types) { where(scan_type: sanitize_scan_types(scan_types)) }
    scope :by_project, ->(project) { where(project: project) }
    scope :by_pipeline_ids, ->(pipeline_ids) { where(pipeline_id: pipeline_ids) }
    scope :without_statuses, ->(statuses) { where.not(status: statuses) }
    scope :including_build, -> { includes(:build) }
    scope :latest, -> { where(latest: true) }
    scope :latest_successful, -> { latest.succeeded }
    scope :by_build_ids, ->(build_ids) { where(build_id: build_ids) }
    scope :without_errors, -> { where("jsonb_array_length(COALESCE(info->'errors', '[]'::jsonb)) = 0") }
    scope :stale, -> { where("created_at < ?", stale_after.ago).where.not(status: :purged) }
    scope :ordered_by_created_at_and_id, -> { order(:created_at, :id) }
    scope :with_warnings, -> { where("jsonb_array_length(COALESCE(info->'warnings', '[]'::jsonb)) > 0") }
    scope :with_errors, -> { where("jsonb_array_length(COALESCE(info->'errors', '[]'::jsonb)) > 0") }
    scope :processing, -> { where(status: %i[created preparing]) }
    scope :partial, -> do
      joins(:partial_scan)
    end

    delegate :name, to: :build
    delegate :mode, to: :partial_scan, prefix: true, allow_nil: true
    alias_attribute :type, :scan_type

    before_save :ensure_project_id_pipeline_id

    def self.distinct_scan_types
      select(:scan_type).distinct.pluck(:scan_type)
    end

    def self.sanitize_scan_types(given_types)
      scan_types.keys & Array(given_types).map(&:to_s)
    end

    def self.pipeline_ids(project, scan_type)
      by_scan_types(scan_type).by_project(project).succeeded.pluck(:pipeline_id)
    end

    def self.projects_with_scans(project_ids)
      Security::Scan.where(project_id: project_ids).distinct.pluck(:project_id)
    end

    def self.results_ready?(pipeline, scan_types = self.scan_types.keys)
      !processing?(pipeline, scan_types) && pipeline.all_security_jobs_complete?
    end

    def self.processing?(pipeline, scan_types)
      by_pipeline_ids(pipeline.self_and_project_descendants.pluck_primary_key)
        .by_scan_types(scan_types)
        .latest
        .processing
        .exists?
    end

    def self.stale_after
      days = Gitlab::CurrentSettings.security_scan_stale_after_days
      days.days
    end

    # If the record is created 3 months ago and purged,
    # it means that all the previous records must be purged
    # as well so the related findings can be dropped.
    def findings_can_be_purged?
      created_at < self.class.stale_after.ago && purged?
    end

    def has_warnings?
      processing_warnings.present?
    end

    def processing_warnings
      info.fetch('warnings', [])
    end

    def processing_warnings=(warnings)
      info['warnings'] = warnings
    end

    def has_errors?
      processing_errors.present?
    end

    def processing_errors
      info.fetch('errors', [])
    end

    def processing_errors=(errors)
      info['errors'] = errors
    end

    def add_processing_error!(error)
      info['errors'] = processing_errors.push(error.stringify_keys)

      save!
    end

    # Returns the findings from the source report
    def report_findings
      @report_findings ||= security_report&.findings.to_a
    end

    def report_primary_identifiers
      @report_primary_identifiers ||= security_report&.primary_identifiers
    end

    def remediations_proxy
      @remediations_proxy ||= RemediationsProxy.new(job_artifact&.file)
    end

    def scanner
      project.vulnerability_scanners.find_by_external_id(security_report&.scanner&.external_id)
    end

    private

    # Accessing the security report actually calls the parsers.
    # For dependency scanning with SBOM artifacts, this can lead to parsing multiple SBOM
    # documents and scanning them dynamically.
    # For multi-run artifacts (SARIF), scanner_external_id selects the right sub-report.
    def security_report
      @security_report ||= fetch_security_report
    end

    def fetch_security_report
      reports = job_artifact&.security_reports
      return unless reports

      if scanner_external_id.present?
        reports.find { |r| r.scanner&.external_id == scanner_external_id && r.type == scan_type }
      else
        reports.first
      end
    end

    def job_artifact
      direct =
        if scan_type == 'dependency_scanning'
          # For DS scans, prefer DS report artifacts over SBOM artifacts
          # This aligns with StoreScansService which skips SBOM processing when DS report exists
          build.job_artifacts.find_by_file_type('dependency_scanning') ||
            build.job_artifacts.find_by_file_type('cyclonedx')
        else
          build.job_artifacts.find_by_file_type(scan_type)
        end

      # SARIF fan-out: a scan persisted from a SARIF artifact has scan_type derived
      # from inference but no matching file_type artifact exists.
      # Fall back to the SARIF artifact to pick the matching sub-report.
      direct || build.job_artifacts.find_by_file_type('sarif')
    end

    def ensure_project_id_pipeline_id
      self.project_id ||= build.project_id
      self.pipeline_id ||= build.commit_id
    end
  end
end
