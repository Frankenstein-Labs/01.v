# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_streaming_http_namespace_filter, class: 'AuditEvents::Streaming::HTTP::NamespaceFilter' do
    namespace { association(:group) }
    external_audit_event_destination { association(:external_audit_event_destination, group: namespace) }
  end
end
