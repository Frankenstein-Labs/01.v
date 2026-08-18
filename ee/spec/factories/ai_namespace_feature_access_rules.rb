# frozen_string_literal: true

FactoryBot.define do
  factory :ai_namespace_feature_access_rules, class: 'Ai::NamespaceFeatureAccessRule' do
    through_namespace { association(:group) }
    association :root_namespace, factory: :group
    accessible_entity { 'duo_classic' }
    created_at { Time.zone.now }
    updated_at { Time.zone.now }

    trait :duo_agent_platform do
      accessible_entity { 'duo_agent_platform' }
    end

    trait :duo_classic do
      accessible_entity { 'duo_classic' }
    end

    trait :default_rule do
      through_namespace { nil }
    end
  end
end
