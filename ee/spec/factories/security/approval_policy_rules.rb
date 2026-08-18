# frozen_string_literal: true

FactoryBot.define do
  scan_finding_content = {
    type: 'scan_finding',
    branches: [],
    scanners: %w[container_scanning],
    vulnerabilities_allowed: 0,
    severity_levels: %w[critical],
    vulnerability_states: %w[detected]
  }.freeze

  factory :approval_policy_rule, class: 'Security::ApprovalPolicyRule' do
    security_policy
    sequence(:rule_index)
    security_policy_management_project_id do
      security_policy.security_orchestration_policy_configuration.security_policy_management_project_id
    end
    scan_finding

    trait :deleted do
      rule_index { -1 }
    end

    trait :scan_finding do
      type { Security::ApprovalPolicyRule.types[:scan_finding] }
      content { scan_finding_content }
    end

    trait :scan_finding_with_enrichment_filters do
      type { Security::ApprovalPolicyRule.types[:scan_finding] }
      content do
        {
          type: 'scan_finding',
          branches: [],
          scanners: %w[container_scanning],
          vulnerabilities_allowed: 0,
          severity_levels: %w[critical],
          vulnerability_states: %w[detected],
          vulnerability_attributes: {
            known_exploited: true
          }
        }
      end
    end

    trait :license_finding do
      type { Security::ApprovalPolicyRule.types[:license_finding] }
      content do
        {
          type: 'license_finding',
          branches: [],
          match_on_inclusion_license: true,
          license_types: %w[BSD MIT],
          license_states: %w[newly_detected detected]
        }
      end
    end

    trait :license_finding_with_allowed_licenses do
      type { Security::ApprovalPolicyRule.types[:license_finding] }
      content do
        {
          type: 'license_finding',
          branches: [],
          license_states: %w[newly_detected detected],
          licenses: {
            allowed: [
              {
                name: "MIT License",
                packages: { excluding: { purls: ["pkg:gem/bundler@1.0.0"] } }
              }
            ]
          }
        }
      end
    end

    trait :license_finding_with_denied_licenses do
      type { Security::ApprovalPolicyRule.types[:license_finding] }
      content do
        {
          type: 'license_finding',
          branches: [],
          license_states: %w[newly_detected detected],
          licenses: {
            denied: [
              {
                name: "MIT License",
                packages: { excluding: { purls: ["pkg:gem/bundler@1.0.0"] } }
              }
            ]
          }
        }
      end
    end

    trait :license_finding_with_current_and_new_keys do
      type { Security::ApprovalPolicyRule.types[:license_finding] }
      content do
        {
          type: 'license_finding',
          branches: [],
          match_on_inclusion_license: true,
          license_types: %w[BSD MIT],
          license_states: %w[newly_detected detected],
          licenses: {
            allowed: [
              {
                name: "MIT License",
                packages: { excluding: { purls: ["pkg:gem/bundler@1.0.0"] } }
              }
            ]
          }
        }
      end
    end

    trait :any_merge_request do
      type { Security::ApprovalPolicyRule.types[:any_merge_request] }
      content do
        {
          type: 'any_merge_request',
          branches: [],
          commits: 'any'
        }
      end
    end

    trait :scan_finding_with_epss_filter do
      scan_finding
      content do
        scan_finding_content.merge(
          vulnerability_attributes: {
            epss_score: { operator: 'greater_than', value: 0.1 }
          }
        )
      end
    end

    trait :scan_finding_with_known_exploited_filter do
      scan_finding
      content do
        scan_finding_content.merge(
          vulnerability_attributes: {
            known_exploited: true
          }
        )
      end
    end
  end
end
