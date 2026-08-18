# frozen_string_literal: true

FactoryBot.modify do
  factory :supply_chain_attestation do
    trait :verification_succeeded do
      verification_checksum { 'abc' }
      verification_state { ::SupplyChain::Attestation.verification_state_value(:verification_succeeded) }

      after(:create) do |instance, _|
        instance.verification_failure = nil
        instance.verification_state = ::SupplyChain::Attestation.verification_state_value(:verification_started)
        instance.supply_chain_attestation_state.supply_chain_attestation = instance
        instance.verification_succeeded!
      end
    end

    trait :verification_failed do
      verification_failure { 'Could not calculate the checksum' }
      verification_state { ::SupplyChain::Attestation.verification_state_value(:verification_failed) }

      #
      # Geo::VerifiableReplicator#after_verifiable_update tries to verify
      # the replicable async and marks it as verification started when the
      # model record is created/updated.
      #
      after(:create) do |instance, evaluator|
        instance.verification_failure = evaluator.verification_failure
        instance.supply_chain_attestation_state.supply_chain_attestation = instance
        instance.verification_failed!
      end
    end

    trait :remote_store do
      file_store { ::SupplyChain::AttestationUploader::Store::REMOTE }
    end
  end
end
