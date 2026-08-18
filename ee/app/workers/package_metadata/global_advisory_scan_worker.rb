# frozen_string_literal: true

module PackageMetadata
  class GlobalAdvisoryScanWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :sticky
    feature_category :software_composition_analysis
    urgency :throttled
    deduplicate :until_executed
    idempotent!
    concurrency_limit -> { 10 }

    def handle_event(event)
      advisory = Advisory.with_affected_packages.find_by_id(event.data[:advisory_id])

      if advisory.nil?
        return logger.error(structured_payload(message: 'Advisory not found.', advisory_id: event.data[:advisory_id]))
      end

      AdvisoryScanService.execute(advisory)
    end
  end
end
