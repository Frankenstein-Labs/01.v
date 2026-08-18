# frozen_string_literal: true

FactoryBot.define do
  factory :scan_profile_project_status, class: 'Security::ScanProfileProjectStatus' do
    project
    scan_profile { association(:security_scan_profile) }
    status { :success }
    consecutive_failure_count { 0 }
    consecutive_success_count { 0 }
  end
end
