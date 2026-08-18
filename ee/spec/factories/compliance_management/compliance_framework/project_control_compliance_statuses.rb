# frozen_string_literal: true

FactoryBot.define do
  factory :project_control_compliance_status,
    class: 'ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus' do
    compliance_requirement { association(:compliance_requirement) }
    project { association(:project, namespace: compliance_requirement.namespace) }
    namespace { project.namespace }
    compliance_requirements_control do
      association(:compliance_requirements_control, compliance_requirement: compliance_requirement)
    end
    status { 'pass' }

    # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- this is not a direct association of the factory created here
    before :create do |status|
      framework = status.compliance_requirement.framework
      project = status.project

      next if project.compliance_framework_settings.where(framework_id: framework.id).exists?

      create(:compliance_framework_project_setting, project: project,
        compliance_management_framework: framework)
    end
    # rubocop:enable RSpec/FactoryBot/StrategyInCallback
  end
end
