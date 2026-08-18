# frozen_string_literal: true

FactoryBot.define do
  factory :geo_packages_debian_project_component_file_state, class: 'Geo::PackagesDebianProjectComponentFileState' do
    packages_debian_project_component_file factory: :debian_project_component_file

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
