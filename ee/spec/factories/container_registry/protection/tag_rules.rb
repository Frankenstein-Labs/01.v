# frozen_string_literal: true

FactoryBot.modify do
  factory :container_registry_protection_tag_rule, class: 'ContainerRegistry::Protection::TagRule' do
    trait :immutable do
      minimum_access_level_for_delete { nil }
      minimum_access_level_for_push { nil }
    end
  end
end
