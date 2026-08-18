# frozen_string_literal: true

FactoryBot.define do
  factory :security_scan_profile, class: 'Security::ScanProfile' do
    name { 'Test Scan Profile' }
    description { 'This is a test scan profile' }
    namespace { association(:group) }
    gitlab_recommended { false }
    scan_type { :sast }

    trait :sast do
      scan_type { :sast }
    end

    trait :dependency_scanning_post_processing do
      scan_type { :dependency_scanning_post_processing }
    end
  end
end
