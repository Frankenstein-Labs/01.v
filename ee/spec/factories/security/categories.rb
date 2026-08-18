# frozen_string_literal: true

FactoryBot.define do
  factory :security_category, class: 'Security::Category' do
    namespace { nil }
    editable_state { :locked }
    template_type { nil }
    multiple_selection { false }
    name { 'Test Category' }
    description { 'This is a test category' }

    trait :single_selection do
      multiple_selection { false }
    end

    trait :multi_selection do
      multiple_selection { true }
    end

    trait :soft_deleted do
      deleted_at { Time.current }
    end
  end
end
