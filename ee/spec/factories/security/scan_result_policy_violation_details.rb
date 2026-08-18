# frozen_string_literal: true

FactoryBot.define do
  factory :scan_result_policy_violation_detail, class: 'Security::ScanResultPolicyViolationDetail' do
    association :violation, factory: :scan_result_policy_violation
    project { violation.project }
    scan_finding

    trait :scan_finding do
      policy_rule_type { :scan_finding }
      finding_uuid { SecureRandom.uuid }
      finding_state { :newly_detected }
    end

    trait :license_scanning do
      policy_rule_type { :license_scanning }
      finding_uuid { nil }
      finding_state { nil }
      license_name { 'MIT' }
      dependencies { ['some-package'] }
      metadata { { Security::ScanResultPolicyViolationDetail::METADATA_COUNT_DEPENDENCIES => dependencies.size } }
    end

    trait :any_merge_request do
      policy_rule_type { :any_merge_request }
      finding_uuid { nil }
      finding_state { nil }
      commit_shas { [SecureRandom.hex(20)] }
      metadata { { Security::ScanResultPolicyViolationDetail::METADATA_COUNT_COMMIT_SHAS => commit_shas.size } }
    end
  end
end
