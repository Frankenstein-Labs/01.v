# frozen_string_literal: true

module Sbom
  class IngestReportsWorker
    include ApplicationWorker

    deduplicate :until_executed, if_deduplicated: :reschedule_once
    idempotent!

    data_consistency :always

    worker_resource_boundary :cpu
    queue_namespace :sbom_reports
    feature_category :dependency_management

    def perform(pipeline_id)
      ::Ci::Pipeline.find_by_id(pipeline_id).try do |pipeline|
        ::Sbom::Ingestion::IngestReportsService.execute(pipeline)
      end
    end
  end
end
