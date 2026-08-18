# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_streaming_instance_namespace_filters, class: 'AuditEvents::Instance::NamespaceFilter' do
    namespace factory: :group
    external_streaming_destination factory: :audit_events_instance_external_streaming_destination
  end
end
