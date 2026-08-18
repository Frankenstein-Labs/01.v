# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_streaming_instance_event_type_filter,
    class: 'AuditEvents::Streaming::InstanceEventTypeFilter' do
    audit_event_type { "event_type_filters_created" }
    instance_external_audit_event_destination
  end
end
