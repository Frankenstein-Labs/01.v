# frozen_string_literal: true

FactoryBot.modify do
  factory :lfs_object do
    trait(:checksummed) do
      association :lfs_object_state, :checksummed, strategy: :build
    end

    trait(:checksum_failure) do
      association :lfs_object_state, :checksum_failure, strategy: :build
    end

    trait(:verification_succeeded) do
      with_file
      verification_checksum { 'abc' }
      verification_state { ::LfsObject.verification_state_value(:verification_succeeded) }
    end

    trait(:verification_failed) do
      with_file
      verification_failure { 'Could not calculate the checksum' }
      verification_state { ::LfsObject.verification_state_value(:verification_failed) }

      # Geo::VerifiableReplicator#after_verifiable_update tries to verify the replicable async and
      # marks it as verification pending when the model record is created/updated.
      #
      # Tip: You must set current node to primary, or else you can get a PG::ForeignKeyViolation
      # because save_verification_details is returning early.
      after(:create) do |instance, evaluator|
        instance.verification_failure = evaluator.verification_failure
        instance.verification_failed!
      end
    end
  end
end
