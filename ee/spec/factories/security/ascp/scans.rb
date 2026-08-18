# frozen_string_literal: true

FactoryBot.define do
  factory :security_ascp_scan, class: 'Security::Ascp::Scan' do
    project
    sequence(:scan_sequence) { |n| n }
    scan_type { :full }
    commit_sha { SecureRandom.hex(20) }

    trait :full do
      scan_type { :full }
    end

    trait :incremental do
      scan_type { :incremental }
      base_commit_sha { SecureRandom.hex(20) }
      base_scan { association(:security_ascp_scan, :full, project: project) }
    end
  end
end
