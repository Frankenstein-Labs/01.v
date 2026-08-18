# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_group_event_type_filters, class: 'AuditEvents::Group::EventTypeFilter' do
    audit_event_type { "event_type_filters_created" }
    external_streaming_destination factory: :audit_events_group_external_streaming_destination
    namespace { external_streaming_destination.group }
  end
end
