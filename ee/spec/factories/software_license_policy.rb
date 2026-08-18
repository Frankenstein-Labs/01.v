# frozen_string_literal: true

FactoryBot.define do
  factory :software_license_policy, class: 'SoftwareLicensePolicy' do
    classification { :allowed }
    project
    approval_policy_rule
    software_license_spdx_identifier { 'MIT' }
    custom_software_license { nil }

    trait :allowed do
      classification { :allowed }
    end

    trait :denied do
      classification { :denied }
    end

    trait :with_apache_license do
      software_license_spdx_identifier { 'Apache-2.0' }
    end

    trait :with_mit_license do
      software_license_spdx_identifier { 'MIT' }
    end
  end
end
