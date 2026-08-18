# frozen_string_literal: true

FactoryBot.define do
  factory :pipl_user, class: 'ComplianceManagement::PiplUser' do
    association :user, factory: [:user, :with_namespace]
    last_access_from_pipl_country_at { Time.current }

    trait :notified do
      initial_email_sent_at { Time.current }
    end

    trait :deletable do
      association :user, factory: [:user, :blocked, :with_namespace]
      initial_email_sent_at { rand(120..140).days.ago } # 140 is not a hard limit, it's just for spec purposes.
    end
  end
end
