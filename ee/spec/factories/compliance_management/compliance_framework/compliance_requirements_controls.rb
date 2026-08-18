# frozen_string_literal: true

FactoryBot.define do
  factory :compliance_requirements_control,
    class: 'ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl' do
    compliance_requirement
    namespace_id { compliance_requirement.namespace_id }
    control_type { 'internal' }
    ping_enabled { true }

    # Default to scanner_sast_running
    name { 'scanner_sast_running' }
    expression { { operator: '=', field: 'scanner_sast_running', value: true }.to_json }

    trait :minimum_approvals_required_1 do
      name { 'minimum_approvals_required_1' }
      expression do
        {
          operator: ">=",
          field: "minimum_approvals_required",
          value: 1
        }.to_json
      end
    end

    trait :minimum_approvals_required_2 do
      name { 'minimum_approvals_required_2' }
      expression do
        {
          operator: ">=",
          field: "minimum_approvals_required",
          value: 2
        }.to_json
      end
    end

    trait :project_visibility_not_internal do
      name { 'project_visibility_not_internal' }
      expression do
        {
          operator: "=",
          field: "project_visibility_not_internal",
          value: true
        }.to_json
      end
    end

    trait :default_branch_protected do
      name { 'default_branch_protected' }
      expression do
        {
          operator: "=",
          field: "default_branch_protected",
          value: true
        }.to_json
      end
    end

    trait :external do
      name { 'external_control' }
      external_control_name { 'external_control_name' }
      external_url { FFaker::Internet.unique.http_url }
      control_type { 'external' }
      secret_token { 'token' }
      ping_enabled { true }
    end

    trait :ping_disabled do
      ping_enabled { false }
    end
  end
end
