# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_read, class: 'Vulnerabilities::Read' do
    vulnerability { association(:vulnerability, report_type: report_type, project: project) }
    vulnerability_occurrence { association(:vulnerabilities_finding, project: project) }
    project factory: :project
    scanner { association(:vulnerabilities_scanner, project: project) }
    report_type { :sast }
    severity { :high }
    state { :detected }
    uuid { SecureRandom.uuid }
    owasp_top_10 { 'undefined' }
    traits_for_enum :dismissal_reason, Vulnerabilities::DismissalReasonEnum.values.keys
    tracked_context { project.security_project_tracked_contexts.first }

    after(:build) do |vulnerability_read, _|
      vulnerability_read.archived = vulnerability_read.project&.archived
      vulnerability_read.traversal_ids = vulnerability_read.project&.namespace&.traversal_ids
    end
  end

  trait :with_finding do
    vulnerability_occurrence { vulnerability.vulnerability_finding }
  end

  trait :with_remediations do
    has_remediations { true }
  end

  trait :with_owasp_top_10 do
    transient do
      owasp_top_10 { "A1:2017-Injection" }
    end

    after(:build) do |vulnerability_read, evaluator|
      vulnerability_read.owasp_top_10 = evaluator.owasp_top_10
    end
  end

  trait :with_identifer_name do
    transient do
      identifier_names { ["CVE-2018-1234"] }
    end

    after(:build) do |vulnerability_read, evaluator|
      vulnerability_read.identifier_names = evaluator.identifier_names
    end
  end
end
