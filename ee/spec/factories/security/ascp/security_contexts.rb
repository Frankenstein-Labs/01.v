# frozen_string_literal: true

FactoryBot.define do
  factory :security_ascp_security_context, class: 'Security::Ascp::SecurityContext' do
    project
    scan { association(:security_ascp_scan, project: project) }
    component { association(:security_ascp_component, project: project, scan: scan) }
    summary { 'Handles user authentication with session-based security' }
    authentication_model { 'Session-based with JWT tokens' }
    authorization_model { 'Role-based access control (RBAC)' }
    data_sensitivity { 'high' }

    trait :with_guidelines do
      # Guideline requires the security_context to exist first (FK constraint)
      # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- requires parent record
      after(:create) do |context, _evaluator|
        create(:security_ascp_security_guideline,
          security_context: context,
          project: context.project,
          scan: context.scan)
      end
      # rubocop:enable RSpec/FactoryBot/StrategyInCallback
    end
  end
end
