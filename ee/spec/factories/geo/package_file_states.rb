# frozen_string_literal: true

FactoryBot.define do
  factory :geo_package_file_state, class: 'Geo::PackageFileState' do
    package_file

    trait(:checksummed) do
      verification_checksum { 'abc' }
    end

    trait(:checksum_failure) do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
