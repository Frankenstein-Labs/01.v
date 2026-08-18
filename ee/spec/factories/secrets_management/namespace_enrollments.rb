# frozen_string_literal: true

FactoryBot.define do
  factory :secrets_manager_namespace_enrollment,
    class: 'SecretsManagement::NamespaceEnrollment' do
    namespace { association(:group) }
  end
end
