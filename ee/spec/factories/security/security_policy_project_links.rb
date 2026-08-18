# frozen_string_literal: true

FactoryBot.define do
  factory :security_policy_project_link, class: 'Security::PolicyProjectLink' do
    project
    security_policy
  end
end
