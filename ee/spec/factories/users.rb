# frozen_string_literal: true

FactoryBot.modify do
  factory :user do
    trait :auditor do
      auditor { true }
    end

    trait :group_managed do
      association :managing_group, factory: :group_with_managed_accounts

      after(:create) do |user, evaluator|
        create(:group_saml_identity,
          user: user,
          saml_provider: user.managing_group.saml_provider
        )
      end
    end

    trait :service_user do
      user_type { :service_user }
    end

    trait :low_risk do
      after(:create) do |user|
        create(:user_custom_attribute,
          key: UserCustomAttribute::ARKOSE_RISK_BAND, value: Arkose::VerifyResponse::RISK_BAND_LOW, user: user
        )
      end
    end

    trait :medium_risk do
      after(:create) do |user|
        create(:user_custom_attribute,
          key: UserCustomAttribute::ARKOSE_RISK_BAND, value: Arkose::VerifyResponse::RISK_BAND_MEDIUM, user: user
        )
      end
    end

    trait :high_risk do
      after(:create) do |user|
        create(:user_custom_attribute,
          key: UserCustomAttribute::ARKOSE_RISK_BAND, value: Arkose::VerifyResponse::RISK_BAND_HIGH, user: user
        )
      end
    end

    trait :identity_verification_eligible do
      created_at { IdentityVerifiable::IDENTITY_VERIFICATION_RELEASE_DATE + 1.day }
    end

    trait :with_compromised_password_detection do
      after(:create) do |user|
        create(:compromised_password_detection, user: user)
      end
    end

    transient do
      skip_ai_prefix_validation { nil }
    end
  end

  factory :omniauth_user do
    transient do
      saml_provider { nil }
    end

    trait :arkose_verified do
      after(:create) do |user|
        create(:user_custom_attribute,
          key: UserCustomAttribute::ARKOSE_RISK_BAND, value: Arkose::VerifyResponse::RISK_BAND_LOW, user: user
        )
      end
    end
  end
end

FactoryBot.define do
  factory :auditor, parent: :user, traits: [:auditor]
  factory :external_user, parent: :user, traits: [:external]
  factory :enterprise_user, parent: :user do
    transient do
      enterprise_group { association(:group) }
    end

    user_detail do
      association :user_detail, :enterprise, enterprise_group: enterprise_group, user: instance
    end
  end

  factory :composite_identity_service_account_for_project, parent: :user, traits: [:service_account] do
    transient do
      project { association(:project) }
    end

    developer_of { project }
    composite_identity_enforced { true }
    provisioned_by_group { project.root_ancestor }
    organization { provisioned_by_group.organization }
  end
end
