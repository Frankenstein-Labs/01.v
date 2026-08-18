# frozen_string_literal: true

FactoryBot.define do
  factory :observability_metrics_issues_connection, class: 'Observability::MetricsIssuesConnection' do
    issue
    metric_name { "Count of students" }
    metric_type { :sum_type }
  end
end
