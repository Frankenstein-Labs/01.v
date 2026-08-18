# frozen_string_literal: true

FactoryBot.define do
  factory :project_security_exclusion, class: 'Security::ProjectSecurityExclusion' do
    scanner { 'secret_push_protection' }
    description { 'basic active exclusion to exclude a certain value from scanning' }

    trait :active do
      active { true }
    end

    trait :inactive do
      active { false }
    end

    trait :with_raw_value do
      type { :raw_value }
      value { '01234567890123456789-glpat'.reverse }
    end

    trait :with_rule do
      type { :rule }
      value { 'gitlab_personal_access_token' }
    end

    trait :with_regex_pattern do
      type { :regex_pattern }
      value { 'SK[0-9a-fA-F]{32}' }
    end

    trait :with_path do
      type { :path }
      value { 'spec/models/project_spec.rb' }
    end
  end
end
