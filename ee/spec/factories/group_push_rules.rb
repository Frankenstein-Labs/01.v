# frozen_string_literal: true

FactoryBot.define do
  factory :group_push_rule do
    group

    trait :commit_message do
      commit_message_regex { "(f|F)ixes #\d+.*" }
    end
  end
end
