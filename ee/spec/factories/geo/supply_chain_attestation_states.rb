# frozen_string_literal: true

FactoryBot.define do
  factory :geo_supply_chain_attestation_state, class: 'Geo::SupplyChainAttestationState' do
    supply_chain_attestation factory: :supply_chain_attestation

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
