# frozen_string_literal: true

FactoryBot.define do
  factory :pm_cve_enrichment_data_object, class: '::PackageMetadata::DataObjects::CveEnrichment' do
    cve_id { 'CVE-2020-1234' }
    epss_score { 0.5 }
    is_known_exploit { false }

    initialize_with do
      new(**attributes)
    end

    skip_create
  end
end
