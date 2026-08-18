# frozen_string_literal: true

FactoryBot.define do
  factory :geo_packages_nuget_symbol_state, class: 'Geo::PackagesNugetSymbolState' do
    packages_nuget_symbol factory: :nuget_symbol

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
