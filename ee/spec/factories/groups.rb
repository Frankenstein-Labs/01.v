# frozen_string_literal: true

FactoryBot.modify do
  factory :group do
    transient do
      # rubocop:disable Lint/EmptyBlock -- block is required by factorybot
      minimal_access {}
      # rubocop:enable Lint/EmptyBlock
    end

    after(:create) do |group, evaluator|
      create(:namespace_settings, namespace: group) unless group.namespace_settings
      create(:namespace_ci_cd_settings, namespace: group) unless group.ci_cd_settings

      if evaluator.minimal_access.present?
        group.add_members(Array.wrap(evaluator.minimal_access),
          ::Gitlab::Access::MINIMAL_ACCESS)
      end
    end

    trait :wiki_repo do
      after(:create) do |group|
        raise 'Failed to create wiki repository!' unless group.create_wiki
      end
    end

    trait(:wiki_enabled) { wiki_access_level { ProjectFeature::ENABLED } }
    trait(:wiki_disabled) { wiki_access_level { ProjectFeature::DISABLED } }
    trait(:wiki_private) { wiki_access_level { ProjectFeature::PRIVATE } }
    trait :model_prompt_cache_enabled do
      after(:create) do |group|
        group.namespace_settings.update!(model_prompt_cache_enabled: true)
      end
    end

    trait :model_prompt_cache_disabled do
      after(:create) do |group|
        group.namespace_settings.update!(model_prompt_cache_enabled: false)
      end
    end

    trait :with_duo_default_on do
      namespace_settings { association(:namespace_settings, duo_availability: 'default_on') }
    end

    trait :with_duo_default_off do
      namespace_settings { association(:namespace_settings, duo_availability: 'default_off') }
    end

    trait :with_duo_never_on do
      namespace_settings { association(:namespace_settings, duo_availability: 'never_on') }
    end

    trait :with_duo_always_on do
      namespace_settings { association(:namespace_settings, duo_availability: 'always_on') }
    end
  end
end

FactoryBot.define do
  factory :group_with_members, parent: :group do
    after(:create) do |group, evaluator|
      group.add_developer(create(:user))
    end
  end

  factory :group_with_ldap, parent: :group do
    transient do
      cn { 'group1' }
      group_access { Gitlab::Access::GUEST }
      provider { 'ldapmain' }
    end

    factory :group_with_ldap_group_link do
      after(:create) do |group, evaluator|
        group.ldap_group_links << create(
          :ldap_group_link,
          cn: evaluator.cn,
          group_access: evaluator.group_access,
          provider: evaluator.provider
        )
      end
    end

    factory :group_with_ldap_group_filter_link do
      after(:create) do |group, evaluator|
        group.ldap_group_links << create(
          :ldap_group_link,
          filter: '(a=b)',
          cn: nil,
          group_access: evaluator.group_access,
          provider: evaluator.provider
        )
      end
    end
  end

  factory :group_with_managed_accounts, parent: :group do
    after(:create) do |group, evaluator|
      create(:saml_provider,
        :enforced_group_managed_accounts,
        group: group)
    end
  end

  factory :group_with_plan, parent: :group do
    transient do
      plan { :free_plan }
      trial { false }
      trial_starts_on { nil }
      trial_ends_on { nil }
    end

    after(:create) do |group, evaluator|
      if evaluator.plan
        create(
          :gitlab_subscription,
          namespace: group,
          hosted_plan: create(evaluator.plan),
          trial: evaluator.trial,
          trial_starts_on: evaluator.trial_starts_on,
          trial_ends_on: evaluator.trial_ends_on
        )
      end
    end
  end
end
