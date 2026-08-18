# frozen_string_literal: true

FactoryBot.define do
  factory :artifact_registry_namespace_mapping, class: 'ArtifactRegistry::NamespaceMapping' do
    organization { association(:common_organization) }
    ar_namespace_id { SecureRandom.uuid }
  end
end
