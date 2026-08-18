# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_streaming_group_namespace_filters, class: 'AuditEvents::Group::NamespaceFilter' do
    external_streaming_destination factory: :audit_events_group_external_streaming_destination
    namespace { external_streaming_destination.group }
  end
end
