# frozen_string_literal: true

FactoryBot.define do
  factory :geo_packages_helm_metadata_cache_state, class: 'Geo::PackagesHelmMetadataCacheState' do
    association :packages_helm_metadata_cache

    trait(:checksummed) do
      verification_checksum { 'abc' }
    end

    trait(:checksum_failure) do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
