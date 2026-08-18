# frozen_string_literal: true

module Cd
  module Versions
    class CreateFromArtifactWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :sticky
      feature_category :continuous_delivery
      deduplicate :until_executed, including_scheduled: true
      concurrency_limit -> { 200 }
      idempotent!

      def handle_event(event)
        ::Cd::Versions::CreateFromArtifactService.new(
          image: event.data.fetch(:image),
          source_ref: event.data.fetch(:source_ref),
          organization_id: event.data.fetch(:organization_id),
          tag: event.data[:tag],
          digest: event.data[:digest]
        ).execute
      end
    end
  end
end
