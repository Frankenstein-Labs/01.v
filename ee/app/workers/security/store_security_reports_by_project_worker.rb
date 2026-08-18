# frozen_string_literal: true

# Worker for storing security reports into the database.
#
module Security
  class StoreSecurityReportsByProjectWorker
    include ApplicationWorker
    include SecurityScansQueue

    data_consistency :always
    sidekiq_options retry: 3
    feature_category :vulnerability_management
    worker_resource_boundary :memory

    idempotent!
    deduplicate :until_executing

    def self.cache_key(project_id: nil)
      return unless project_id.present?

      "#{name}::latest_pipeline_with_security_reports::#{project_id}"
    end

    def perform(project_id)
      project = Project.find_by_id(project_id)
      return unless project&.can_store_security_reports?

      pipeline = latest_pipeline_with_security_reports(project.id)

      # Technically possible since this is an async job and pipelines
      # can be deleted between when this job was scheduled and
      # run;very unlikely
      return unless pipeline

      ::Security::Ingestion::IngestReportsService.execute(pipeline)
      SecretDetection::GitlabTokenVerificationWorker.perform_async(pipeline.id)
    end

    private

    def latest_pipeline_with_security_reports(project_id)
      self.class.cache_key(project_id: project_id)
        .then { |cache_key| Gitlab::Redis::SharedState.with { |redis| redis.get(cache_key) } }
        # not strictly necessary, but to prevent coercing nil to id 0
        .then { |pipeline_id_string| pipeline_id_string.blank? ? nil : pipeline_id_string.to_i }
        .then { |pipeline_id| Ci::Pipeline.find_by_id(pipeline_id) }
    end
  end
end
