# frozen_string_literal: true

FactoryBot.define do
  factory :namespace_secret_count, class: 'SecretsManagement::NamespaceSecretCount' do
    namespace { association(:group) }
    root_namespace { namespace&.root_ancestor }
    count { 0 }
  end
end
