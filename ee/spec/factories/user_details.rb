# frozen_string_literal: true

FactoryBot.modify do
  factory :user_detail do
    trait :enterprise do
      enterprise_group { association(:group) }
      enterprise_group_associated_at { Time.current }
    end
  end
end
