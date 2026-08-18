# frozen_string_literal: true

FactoryBot.define do
  factory :observability_traces_issues_connection, class: 'Observability::TracesIssuesConnection' do
    issue
    trace_identifier { "fa12d360-54cd-c4db-5241-ccf7841d3e72" }
  end
end
