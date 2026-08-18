# frozen_string_literal: true

module AuditEvents
  module Instance
    class EventTypeFilter < ApplicationRecord
      include AuditEvents::Streaming::StreamableEventTypeFilter

      self.table_name = 'audit_events_instance_streaming_event_type_filters'

      belongs_to :external_streaming_destination, class_name: 'ExternalStreamingDestination'

      validates :audit_event_type,
        presence: true,
        length: { maximum: 255 },
        uniqueness: { scope: :external_streaming_destination_id }
    end
  end
end
