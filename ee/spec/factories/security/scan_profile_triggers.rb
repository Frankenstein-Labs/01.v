# frozen_string_literal: true

FactoryBot.define do
  factory :security_scan_profile_trigger, class: 'Security::ScanProfileTrigger' do
    scan_profile { association(:security_scan_profile) }
    namespace { scan_profile.namespace }
    trigger_type { :default_branch_pipeline }

    transient do
      configuration_values { nil }
    end

    configuration do
      next unless configuration_values

      association(:security_scan_profile_configuration,
        scan_profile: scan_profile, configuration: configuration_values)
    end

    trait :sbom_ingested do
      scan_profile do
        association(:security_scan_profile, :dependency_scanning_post_processing)
      end
      trigger_type { :sbom_ingested }
    end
  end
end
