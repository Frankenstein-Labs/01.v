# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_subscription_add_on_purchase, class: 'GitlabSubscriptions::AddOnPurchase' do
    add_on { association(:gitlab_subscription_add_on) }
    subscription_add_on_uid { add_on&.name_before_type_cast }
    organization { namespace ? namespace.organization : association(:common_organization) }
    namespace { association(:group) }
    quantity { 1 }
    started_at { Time.current }
    expires_on { 60.days.from_now }
    purchase_xid { SecureRandom.hex(16) }
    trial { false }

    trait :active do
      started_at { 1.day.ago.to_date }
      expires_on { 1.year.from_now.to_date }
    end

    trait :trial do
      trial { true }
      expires_on { 60.days.from_now.to_date }
    end

    trait :active_trial do
      trial
      active
    end

    trait :expired do
      started_at { 5.days.ago.to_date }
      expires_on { 1.day.ago.to_date }
    end

    trait :expired_trial do
      trial
      expired
    end

    trait :future_dated do
      started_at { 1.month.from_now.to_date }
      expires_on { 1.year.from_now.to_date }
    end

    trait :product_analytics do
      add_on { association(:gitlab_subscription_add_on, :product_analytics) }
    end

    trait :code_suggestions do
      add_on { association(:gitlab_subscription_add_on, :code_suggestions) }
    end

    trait :duo_core do
      add_on { association(:gitlab_subscription_add_on, :duo_core) }
    end

    trait :duo_pro do
      add_on { association(:gitlab_subscription_add_on, :duo_pro) }
    end

    trait :duo_enterprise do
      add_on { association(:gitlab_subscription_add_on, :duo_enterprise) }
    end

    trait :duo_amazon_q do
      add_on { association(:gitlab_subscription_add_on, :duo_amazon_q) }
    end

    trait :self_hosted_dap do
      add_on { association(:gitlab_subscription_add_on, :self_hosted_dap) }
    end

    trait :gitlab_credits do
      add_on { association(:gitlab_subscription_add_on, :gitlab_credits) }
    end

    trait :secrets_manager do
      add_on { association(:gitlab_subscription_add_on, :secrets_manager) }
    end

    trait :self_managed do
      namespace { nil }
    end
  end
end
