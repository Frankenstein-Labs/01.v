# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_license, class: "Gitlab::License" do
    skip_create

    trait :trial do
      block_changes_at { nil }
      starts_at { Date.current }
      expires_at { starts_at.advance(days: 30) }
      restrictions do
        seats_attrs = seats ? { active_user_count: seats } : {}

        {
          add_ons: { 'GitLab_FileLocks' => 1, 'GitLab_Auditor_User' => 1 },
          plan: plan,
          subscription_id: '0000',
          subscription_name: subscription_name,
          trial: true
        }.merge(seats_attrs)
      end
    end

    trait :expired do
      expires_at { 3.weeks.ago.to_date }
    end

    trait :recently_expired do
      expires_at { 3.days.ago.to_date }
    end

    trait :legacy do
      cloud_licensing_enabled { false }
    end

    trait :cloud do
      cloud_licensing_enabled { true }
    end

    trait :offline do
      cloud_licensing_enabled { true }
      offline_cloud_licensing_enabled { true }
    end

    trait :online do
      cloud_licensing_enabled { true }
      offline_cloud_licensing_enabled { false }
    end

    transient do
      plan { License::PREMIUM_PLAN }
      seats { nil }
      subscription_name { 'A-S00000123' }
    end

    starts_at { Date.new(1970, 1, 1) }
    expires_at { Date.current + 11.months }
    block_changes_at { expires_at ? expires_at + 2.weeks : nil }
    notify_users_at  { expires_at }
    notify_admins_at { expires_at }

    licensee do
      {
        "Name" => generate(:name),
        "Email" => generate(:email),
        "Company" => "Company name"
      }
    end

    restrictions do
      seats_attrs = seats ? { active_user_count: seats } : {}

      {
        add_ons: {
          'GitLab_FileLocks' => 1,
          'GitLab_Auditor_User' => 1
        },
        plan: plan,
        subscription_id: '0000',
        subscription_name: subscription_name
      }.merge(seats_attrs)
    end
  end
end
