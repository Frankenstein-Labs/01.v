# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_bot

FactoryBot.define do
  factory :push_rule do
    deny_delete_tag { false }
    project

    trait :commit_message do
      commit_message_regex { "(f|F)ixes #\d+.*" }
    end

    trait :author_email do
      author_email_regex { '.*@veryspecificdomain.com' }
    end

    factory :push_rule_sample do
      is_sample { true }
    end
  end
end
