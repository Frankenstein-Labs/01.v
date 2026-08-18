# frozen_string_literal: true

module DependencyManagement
  module SecurityUpdate
    # Emits an Internal Event for the bottom of the auto-remediation funnel
    # (an auto-remediation MR being merged or closed). Including workers supply
    # the event name via EVENT_NAME.
    module TracksAutoRemediationMrEvent
      extend ActiveSupport::Concern
      include Gitlab::EventStore::Subscriber
      include Gitlab::InternalEventsTracking

      included do
        feature_category :dependency_management
        data_consistency :sticky
        urgency :low
        deduplicate :until_executing, including_scheduled: true
        defer_on_database_health_signal :gitlab_sec,
          [:vulnerability_merge_request_links, :sbom_occurrences], 1.minute
      end

      def handle_event(event)
        merge_request = MergeRequest.find_by_id(event.data[:merge_request_id])
        return unless merge_request

        track_internal_event(
          self.class::EVENT_NAME,
          project: merge_request.project,
          additional_properties: {
            purl_type: purl_type_for(merge_request),
            merge_request_id: merge_request.id
          }
        )
      end

      private

      def purl_type_for(merge_request)
        merge_request.vulnerability_merge_request_links
          .first&.vulnerability&.sbom_occurrences&.first&.purl_type
      end
    end
  end
end
