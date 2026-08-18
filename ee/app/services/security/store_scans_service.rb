# frozen_string_literal: true

module Security
  class StoreScansService
    include ::Gitlab::Utils::StrongMemoize

    def self.execute(pipeline)
      new(pipeline).execute
    end

    def initialize(pipeline)
      @pipeline = pipeline
    end

    def execute
      return if already_purged?

      store_security_scans
      store_sbom_scans

      schedule_store_reports_worker
      schedule_scan_security_report_secrets_worker
      schedule_update_token_status_worker

      publish_reports_ingested_event
    end

    private

    attr_reader :pipeline

    delegate :project, to: :pipeline, private: true

    def store_security_scans
      security_report_artifacts.map do |file_type, artifacts|
        StoreGroupedScansService.execute(artifacts, pipeline, file_type)
      end
    end

    def store_sbom_scans
      return [] if sbom_report_artifacts.blank?

      sbom_report_artifacts.map do |file_type, artifacts|
        StoreGroupedSbomScansService.execute(artifacts, pipeline, file_type)
      end
    end

    def already_purged?
      pipeline.security_scans.purged.any?
    end

    def grouped_report_artifacts
      pipeline.job_artifacts
        .security_reports(file_types: security_report_file_types)
        .group_by(&:file_type)
    end
    strong_memoize_attr :grouped_report_artifacts

    def security_report_artifacts
      grouped_report_artifacts.reject { |file_type| file_type == 'cyclonedx' || !parse_report_file?(file_type) }
    end
    strong_memoize_attr :security_report_artifacts

    def sbom_report_artifacts
      grouped_report_artifacts['cyclonedx']&.each_with_object({}) do |artifact, object|
        next if artifact.security_report.blank? || !parse_report_file?(artifact.security_report.type.to_s)

        # Skip SBOM reports from jobs that already have a dependency_scanning security report.
        # This avoids duplicate scanning and ingestion errors.
        # See https://gitlab.com/gitlab-org/gitlab/-/work_items/546429#note_2992962734
        next if job_ids_with_dependency_scanning.include?(artifact.job_id)

        (object[artifact.security_report.type.to_s] ||= []) << artifact
      end
    end
    strong_memoize_attr :sbom_report_artifacts

    def job_ids_with_dependency_scanning
      security_report_artifacts['dependency_scanning']&.map(&:job_id)&.to_set || Set.new
    end
    strong_memoize_attr :job_ids_with_dependency_scanning

    def security_report_file_types
      Enums::Ci::JobArtifact.security_report_and_cyclonedx_report_file_types
    end

    def parse_report_file?(file_type)
      project.feature_available?(Ci::Build::LICENSED_PARSER_FEATURES.fetch(file_type))
    end

    def schedule_store_reports_worker
      return unless Security::Ingestion.ingest_pipeline?(pipeline)

      Gitlab::Redis::SharedState.with do |redis|
        redis.set(Security::StoreSecurityReportsByProjectWorker.cache_key(project_id: project.id), pipeline.id)
      end

      Security::StoreSecurityReportsByProjectWorker.perform_async(project.id)
    end

    def schedule_scan_security_report_secrets_worker
      ScanSecurityReportSecretsWorker.perform_async(pipeline.id) if revoke_secret_detection_token?
    end

    def schedule_update_token_status_worker
      return unless should_update_token_status?

      Security::SecretDetection::GitlabTokenVerificationWorker.perform_async(pipeline.id)
    end

    def should_update_token_status?
      !pipeline.default_branch? &&
        project.security_setting&.validity_checks_enabled &&
        secret_detection_scans_found?
    end

    def revoke_secret_detection_token?
      pipeline.project.public? &&
        ::Gitlab::CurrentSettings.secret_detection_token_revocation_enabled? &&
        secret_detection_scans_found?
    end

    def secret_detection_scans_found?
      pipeline.security_scans.by_scan_types(:secret_detection).any?
    end

    def publish_reports_ingested_event
      ::Gitlab::EventStore.publish(
        Security::ReportsIngestedEvent.new(data: { pipeline_id: pipeline.id })
      )
    end
  end
end
