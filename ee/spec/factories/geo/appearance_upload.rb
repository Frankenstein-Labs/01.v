# frozen_string_literal: true

FactoryBot.define do
  factory :geo_appearance_upload, class: 'Geo::AppearanceUpload' do
    # Upload partition tables are read-only. Data is written through the
    # Upload model to the uploads parent table, and PostgreSQL routes the
    # row to the correct partition by model_type.
    #
    # This factory creates a regular Upload with the appropriate model
    # association, then returns the record from the partition table.
    transient do
      # Appearance is an instance-wide singleton (validate :single_appearance_row), so reuse
      # the existing row when present. Multiple appearance uploads attach to the one Appearance.
      # rubocop:disable RSpec/FactoryBot/InlineAssociation -- read-only partition, see comment above
      parent_model { Appearance.current_without_cache || create(:appearance) }
      # rubocop:enable RSpec/FactoryBot/InlineAssociation
    end

    initialize_with do
      upload = create(:upload, :with_file, model: parent_model)
      Geo::AppearanceUpload.find(upload.id)
    end

    trait :remote_store do
      initialize_with do
        upload = create(:upload, :object_storage, model: parent_model)
        Geo::AppearanceUpload.find(upload.id)
      end
    end

    # Verification state is stored in a separate state table
    # (Geo::AppearanceUploadState), not on the model itself.
    trait(:verification_succeeded) do
      after(:create) do |instance|
        state = instance.appearance_upload_state
        state.verification_checksum = 'abc'
        state.verification_state = Geo::AppearanceUpload.verification_state_value(:verification_succeeded)
        state.save!
      end
    end

    trait(:verification_failed) do
      after(:create) do |instance|
        state = instance.appearance_upload_state
        state.verification_failure = 'Could not calculate the checksum'
        state.verification_state = Geo::AppearanceUpload.verification_state_value(:verification_failed)
        state.save!
      end
    end

    to_create { |instance| instance } # already persisted via initialize_with
  end
end
