# frozen_string_literal: true

FactoryBot.define do
  factory :gitlab_subscription_history, class: 'GitlabSubscriptions::SubscriptionHistory' do
    association :namespace, factory: :group_with_plan, plan: :premium_plan

    after(:build) do |history|
      gitlab_subscription = history.namespace.gitlab_subscription
      history.gitlab_subscription_id = SecureRandom.random_number(100_000)

      history.gitlab_subscription_id = gitlab_subscription.id if history.namespace.gitlab_subscription.present?
    end

    trait :update do
      change_type { :gitlab_subscription_updated }
    end

    trait :destroyed do
      change_type { :gitlab_subscription_destroyed }
    end
  end
end
