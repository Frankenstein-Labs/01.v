# frozen_string_literal: true

module Cd
  module ArtifactSources
    # Bridges a container registry push onto the source-agnostic
    # Cd::ArtifactPublishedEvent. External artifact sources can publish the
    # same event directly, without going through the container registry.
    class PublishFromRegistryWorker
      include Gitlab::EventStore::Subscriber

      data_consistency :sticky
      feature_category :continuous_delivery
      deduplicate :until_executed, including_scheduled: true
      concurrency_limit -> { 200 }
      idempotent!

      def self.dispatch?(event)
        return false unless Feature.enabled?(:ai_native_deploy, event.project)

        event.data[:tag].present? && event.data[:digest].present? && event.data[:repository].present?
      end

      def handle_event(event)
        project = Project.find_by_id(event.data[:project_id])
        return unless project

        ::Gitlab::EventStore.publish(
          ::Cd::ArtifactPublishedEvent.new(data: {
            image: event.data.fetch(:image),
            source_ref: event.data.fetch(:repository),
            digest: event.data.fetch(:digest),
            organization_id: project.organization_id,
            tag: event.data[:tag],
            published_at: Time.current.utc.iso8601
          }.compact)
        )
      end
    end
  end
end
