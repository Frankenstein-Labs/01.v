# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_instance_event_type_filters, class: 'AuditEvents::Instance::EventTypeFilter' do
    audit_event_type { "event_type_filters_created" }
    external_streaming_destination factory: :audit_events_instance_external_streaming_destination
  end
end
