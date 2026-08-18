# frozen_string_literal: true

FactoryBot.define do
  factory :project_requirement_compliance_status,
    class: 'ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus' do
    compliance_requirement { association(:compliance_requirement) }
    compliance_framework { compliance_requirement.framework }
    project { association(:project, namespace: compliance_requirement.namespace) }
    namespace { project.group }
    pass_count { 1 }
    fail_count { 2 }
    pending_count { 1 }

    # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- this is not a direct association of the factory created here
    trait :with_control_status do
      after(:create) do |status|
        create(:project_control_compliance_status,
          compliance_requirement: status.compliance_requirement,
          project: status.project,
          namespace: status.namespace,
          requirement_status: status)
      end
    end

    before :create do |status|
      framework = status.compliance_framework
      project = status.project

      next if project.compliance_framework_settings.where(framework_id: framework.id).exists?

      create(:compliance_framework_project_setting, project: project,
        compliance_management_framework: framework)
    end
    # rubocop:enable RSpec/FactoryBot/StrategyInCallback
  end
end
