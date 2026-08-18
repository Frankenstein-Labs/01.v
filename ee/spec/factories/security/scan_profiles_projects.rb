# frozen_string_literal: true

FactoryBot.define do
  factory :security_scan_profile_project, class: 'Security::ScanProfileProject' do
    scan_profile { association :security_scan_profile }
    project
  end
end
