# frozen_string_literal: true

FactoryBot.define do
  factory :security_finding_enrichment, class: 'Security::FindingEnrichment' do
    association :project
    cve { "CVE-2025-#{rand(1000..99999)}" }
    finding_uuid { create(:security_finding).uuid }
    cve_enrichment_id { nil }
    epss_score { nil }
    is_known_exploit { nil }
    vulnerability { nil }

    trait :with_vulnerability do
      association :vulnerability
    end
  end
end
