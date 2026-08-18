# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_streaming_http_instance_namespace_filter,
    class: 'AuditEvents::Streaming::HTTP::Instance::NamespaceFilter' do
    namespace { association(:group) }
    instance_external_audit_event_destination { association(:instance_external_audit_event_destination) }
  end
end
