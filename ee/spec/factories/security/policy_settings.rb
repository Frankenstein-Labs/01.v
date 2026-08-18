# frozen_string_literal: true

FactoryBot.define do
  factory :security_policy_settings, class: '::Security::PolicySetting' do
    organization
    csp_namespace { nil }
  end
end
