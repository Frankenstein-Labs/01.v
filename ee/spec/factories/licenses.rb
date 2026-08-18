# frozen_string_literal: true

FactoryBot.define do
  factory :license do
    transient do
      plan { nil }
      expired { false }
      trial { false }
      seats { nil }
      recently_expired { false }
      subscription_name { 'A-S00000123' }
    end

    data do
      traits = []
      traits << :trial if trial
      traits << :expired if expired
      traits << :cloud if cloud
      traits << :recently_expired if recently_expired

      build(:gitlab_license, *traits, plan: plan, seats: seats, subscription_name: subscription_name).export
    end

    # Disable validations when creating an expired license key
    to_create { |instance| instance.save!(validate: !expired) }

    trait :trial do
      trial { true }
    end

    trait :ultimate do
      plan { License::ULTIMATE_PLAN }
    end

    trait :ultimate_trial do
      ultimate
      trial
    end

    # NOTE: these are non-trial licenses, so License#trial? returns nil (not false) --
    # the :trial restriction is only set when `trial` is truthy (see the `data` block
    # above). Assert with `be_falsey` rather than `eq(false)`.
    trait :expired_paid do
      expired { true }
      plan { License::PREMIUM_PLAN }
    end

    trait :active_paid do
      plan { License::PREMIUM_PLAN }
    end
  end
end
