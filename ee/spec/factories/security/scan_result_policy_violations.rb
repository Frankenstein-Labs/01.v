# frozen_string_literal: true

FactoryBot.define do
  factory :scan_result_policy_violation, class: 'Security::ScanResultPolicyViolation' do
    project
    merge_request
    scan_result_policy_read
    violation_data { { "violations" => { "any_merge_request" => { "commits" => ["f89a4ed7"] } } } }

    trait :any_merge_request

    trait :license_scanning do
      violation_data { { "violations" => { "license_scanning" => { "MIT" => %w[A B] } } } }
    end

    trait :new_scan_finding do
      transient do
        uuids { [] }
        validation_context { nil }
      end

      violation_data do
        { "violations" => { "scan_finding" => { "uuids" => { "newly_detected" => uuids } } },
          "context" => validation_context }.compact_blank
      end
    end

    trait :previous_scan_finding do
      transient do
        uuids { [] }
      end

      violation_data { { "violations" => { "scan_finding" => { "uuids" => { "previously_existing" => uuids } } } } }
    end

    trait :with_errors do
      violation_data do
        { 'errors' => [
          { error: Security::ScanResultPolicyViolation::ERRORS[:scan_removed], missing_scans: ['secret_detection'] }
        ] }
      end
    end
  end
end
