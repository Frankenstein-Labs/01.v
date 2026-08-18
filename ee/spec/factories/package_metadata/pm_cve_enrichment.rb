# frozen_string_literal: true

FactoryBot.define do
  factory :pm_cve_enrichment, class: 'PackageMetadata::CveEnrichment' do
    sequence(:cve) { |n| "CVE-1234-#{1234 + n}" }
    epss_score { 12.34 }
    is_known_exploit { false }
  end
end
