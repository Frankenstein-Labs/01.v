# frozen_string_literal: true

FactoryBot.define do
  factory :observability_logs_issues_connection, class: 'Observability::LogsIssuesConnection' do
    issue
    service_name { "foobar" }
    severity_number { 9 }
    log_timestamp { 1.day.ago.to_date }
    trace_identifier { "fa12d360-54cd-c4db-5241-ccf7841d3e72" }
    log_fingerprint { "03fe551c28e5c64b" }
  end
end
