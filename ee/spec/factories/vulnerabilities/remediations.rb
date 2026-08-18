# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerabilities_remediation, class: 'Vulnerabilities::Remediation' do
    transient do
      findings { [] }
    end

    project
    summary { 'Remediation Summary' }
    file { fixture_file_upload('ee/spec/fixtures/vulnerabilities/remediation_patch.b64') }

    sequence :checksum do |i|
      Digest::SHA256.hexdigest(i.to_s)
    end

    after(:create) do |remediation, evaluator|
      evaluator.findings.each do |finding|
        create(:vulnerability_finding_remediation,
          remediation: remediation,
          finding: finding
        )
      end
    end
  end
end
