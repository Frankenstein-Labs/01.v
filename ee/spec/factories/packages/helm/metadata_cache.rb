# frozen_string_literal: true

FactoryBot.modify do
  factory :helm_metadata_cache do
    with_file

    # Verification state lives on the separate state table
    # (Geo::PackagesHelmMetadataCacheState), not on the model itself.
    # With immutable? returning false, the after_create_commit callback
    # calls verify_async which resets state to verification_pending,
    # overwriting build-time attributes. Using after(:create) with
    # direct state table persistence ensures traits survive the callback.
    trait(:verification_succeeded) do
      after(:create) do |instance|
        state = instance.packages_helm_metadata_cache_state
        state.verification_checksum = 'abc'
        state.verification_state = Packages::Helm::MetadataCache.verification_state_value(:verification_succeeded)
        state.save!
      end
    end

    trait(:verification_failed) do
      after(:create) do |instance|
        state = instance.packages_helm_metadata_cache_state
        state.verification_failure = 'Could not calculate the checksum'
        state.verification_state = Packages::Helm::MetadataCache.verification_state_value(:verification_failed)
        state.save!
      end
    end
  end
end
