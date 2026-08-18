# frozen_string_literal: true

module Security
  class StoreScansWorker # rubocop:disable Scalability/IdempotentWorker
    include ApplicationWorker

    data_consistency :always

    worker_resource_boundary :cpu
    sidekiq_options retry: 3
    include SecurityScansQueue

    feature_category :vulnerability_management

    def perform(pipeline_id)
      ::Ci::Pipeline.find_by_id(pipeline_id).try do |pipeline|
        break unless pipeline.project.can_store_security_reports?

        Security::StoreScansService.execute(pipeline)
      end
    end
  end
end
