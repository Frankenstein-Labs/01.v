# frozen_string_literal: true

FactoryBot.define do
  sequence(:vulnerability_scanner_external_id) do |n|
    "find_sec_bugs_#{n}"
  end

  factory :vulnerabilities_scanner, class: 'Vulnerabilities::Scanner' do
    sequence(:external_id) { generate(:vulnerability_scanner_external_id) }
    name { 'Find Security Bugs' }
    vendor { 'Security Vendor' }
    project

    trait :sbom_scanner do
      external_id { Gitlab::VulnerabilityScanning::SecurityScanner::EXTERNAL_ID }
      name { Gitlab::VulnerabilityScanning::SecurityScanner::NAME }
      vendor { Gitlab::VulnerabilityScanning::SecurityScanner::VENDOR }
    end

    trait :cs_scanner do
      external_id { 'trivy' }
      name { 'Trivy' }
      vendor { 'AquaSecurity' }
    end

    trait :dast_scanner do
      external_id { 'browserker' }
      name { 'Browserker' }
      vendor { 'GitLab' }
    end

    trait :sast_scanner do
      external_id { 'find_sec_bugs' }
    end
  end
end
