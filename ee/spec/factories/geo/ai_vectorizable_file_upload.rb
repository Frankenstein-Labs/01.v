# frozen_string_literal: true

FactoryBot.define do
  factory :geo_ai_vectorizable_file_upload, class: 'Geo::AiVectorizableFileUpload' do
    # Upload partition tables are read-only. Data is written through the
    # Upload model to the uploads parent table, and PostgreSQL routes the
    # row to the correct partition by model_type.
    #
    # This factory creates a regular Upload with the appropriate model
    # association, then returns the record from the partition table.
    transient do
      parent_model { create(:ai_vectorizable_file) } # rubocop:disable RSpec/FactoryBot/InlineAssociation -- See above
    end

    initialize_with do
      # The ai_vectorizable_file factory mounts a file via CarrierWave,
      # which creates an Upload row routed to the partition table.
      # We delete it and create a standard :with_file upload so the
      # checksum matches shared example expectations.
      ::Upload.where(model_id: parent_model.id, model_type: 'Ai::VectorizableFile').delete_all
      upload = create(:upload, :with_file, model: parent_model)
      Geo::AiVectorizableFileUpload.find(upload.id)
    end

    trait :remote_store do
      initialize_with do
        ::Upload.where(model_id: parent_model.id, model_type: 'Ai::VectorizableFile').delete_all
        upload = create(:upload, :object_storage, model: parent_model)
        Geo::AiVectorizableFileUpload.find(upload.id)
      end
    end

    # Verification state is stored in a separate state table
    # (Geo::AiVectorizableFileUploadState), not on the model itself.
    trait(:verification_succeeded) do
      after(:create) do |instance|
        state = instance.ai_vectorizable_file_upload_state
        state.verification_checksum = 'abc'
        state.verification_state = Geo::AiVectorizableFileUpload.verification_state_value(:verification_succeeded)
        state.save!
      end
    end

    trait(:verification_failed) do
      after(:create) do |instance|
        state = instance.ai_vectorizable_file_upload_state
        state.verification_failure = 'Could not calculate the checksum'
        state.verification_state = Geo::AiVectorizableFileUpload.verification_state_value(:verification_failed)
        state.save!
      end
    end

    to_create { |instance| instance } # already persisted via initialize_with
  end
end
