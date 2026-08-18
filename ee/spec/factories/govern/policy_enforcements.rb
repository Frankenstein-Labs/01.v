# frozen_string_literal: true

FactoryBot.define do
  factory :govern_policy_enforcement, class: 'Govern::PolicyEnforcement' do
    policy { association(:govern_policy) }
    organization { policy.organization }
    project { association(:project, namespace: policy.namespace) }
  end
end
