# frozen_string_literal: true

FactoryBot.define do
  sequence(:saml_group_name) { |n| "saml-group#{n}" }
  sequence(:saml_provider_name) { |n| "saml_#{n}" }

  factory :saml_group_link do
    saml_group_name { generate(:saml_group_name) }
    access_level { Gitlab::Access::GUEST }
    group

    trait :with_provider do
      provider { generate(:saml_provider_name) }
    end

    trait :with_scim_group_uid do
      scim_group_uid { "5a985f3c-24c4-4b07-96f3-406df371c8f4" }
    end
  end
end
