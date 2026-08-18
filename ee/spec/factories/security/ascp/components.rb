# frozen_string_literal: true

FactoryBot.define do
  factory :security_ascp_component, class: 'Security::Ascp::Component' do
    project
    scan { association(:security_ascp_scan, project: project) }
    title { 'User Authentication Module' }
    sequence(:sub_directory) { |n| "app/services/auth_#{n}" }
    description { 'Handles user authentication' }
    expected_user_behavior { 'Users authenticate with email and password' }

    trait :with_security_context do
      # Security context requires the component to exist first (FK constraint)
      # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- requires parent record
      after(:create) do |component, _evaluator|
        create(:security_ascp_security_context,
          component: component,
          project: component.project,
          scan: component.scan)
      end
      # rubocop:enable RSpec/FactoryBot/StrategyInCallback
    end
  end
end
