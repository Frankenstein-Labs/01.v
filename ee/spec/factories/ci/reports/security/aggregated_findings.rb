# frozen_string_literal: true

FactoryBot.define do
  factory :ci_reports_security_aggregated_findings, class: 'Gitlab::Ci::Reports::Security::AggregatedFinding' do
    pipeline factory: :ci_pipeline
    findings { FactoryBot.build_list(:security_finding, 1) }

    skip_create

    initialize_with do
      ::Gitlab::Ci::Reports::Security::AggregatedFinding.new(pipeline, findings)
    end
  end
end
