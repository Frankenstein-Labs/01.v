# frozen_string_literal: true

FactoryBot.modify do
  factory :nuget_symbol do
    trait :verification_succeeded do
      verification_checksum { 'abc' }
      verification_state { ::Packages::Nuget::Symbol.verification_state_value(:verification_succeeded) }

      after(:create) do |instance, _|
        instance.verification_failure = nil
        instance.verification_state = ::Packages::Nuget::Symbol.verification_state_value(:verification_started)
        instance.packages_nuget_symbol_state.packages_nuget_symbol = instance
        instance.verification_succeeded!
      end
    end

    trait :verification_failed do
      verification_failure { 'Could not calculate the checksum' }
      verification_state { ::Packages::Nuget::Symbol.verification_state_value(:verification_failed) }

      # Geo::VerifiableReplicator#after_verifiable_update tries to verify the replicable async and
      # marks it as verification pending when the model record is created/updated.
      #
      # Tip: You must set current node to primary, or else you can get a PG::ForeignKeyViolation
      # because save_verification_details is returning early.
      after(:create) do |instance, evaluator|
        instance.verification_failure = evaluator.verification_failure
        instance.packages_nuget_symbol_state.packages_nuget_symbol = instance
        instance.verification_failed!
      end
    end
  end
end
