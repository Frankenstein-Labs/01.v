# frozen_string_literal: true

module Sbom
  class DeleteExpiredExportsWorker
    include ApplicationWorker
    # rubocop:disable Scalability/CronWorkerContext -- This job does not require context
    include CronjobQueue

    # rubocop:enable Scalability/CronWorkerContext

    idempotent!

    worker_resource_boundary :cpu
    data_consistency :sticky
    feature_category :dependency_management

    def perform
      Dependencies::DependencyListExport.expired.each_batch do |batch|
        batch.tap { |exports| Upload.destroy_for_associations!(exports) }
             .delete_all
      end
    end
  end
end
