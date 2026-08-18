# frozen_string_literal: true

FactoryBot.define do
  factory :security_scan_profile_configuration, class: 'Security::ScanProfiles::Configuration' do
    scan_profile { association(:security_scan_profile) }
    namespace { scan_profile.namespace }
    configuration { {} }
    configuration_version { 1 }
  end
end
