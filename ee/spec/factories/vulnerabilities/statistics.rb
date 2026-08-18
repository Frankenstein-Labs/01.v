# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_statistic, class: 'Vulnerabilities::Statistic' do
    project
    traversal_ids { project.namespace.traversal_ids }
    initialize_with { Vulnerabilities::Statistic.find_or_initialize_by(project_id: project.id) }

    after(:build) do |vulnerability_statistic, _|
      vulnerability_statistic.archived = vulnerability_statistic.project&.archived
      vulnerability_statistic.total = [
        vulnerability_statistic.low,
        vulnerability_statistic.medium,
        vulnerability_statistic.high,
        vulnerability_statistic.critical,
        vulnerability_statistic.unknown,
        vulnerability_statistic.info
      ].sum
    end

    trait :grade_a do
      info { 1 }
    end

    trait :grade_b do
      low { 1 }
    end

    trait :grade_c do
      medium { 1 }
    end

    trait :grade_d do
      high { 1 }
      unknown { 1 }
    end

    trait :grade_f do
      critical { 1 }
    end
  end
end
