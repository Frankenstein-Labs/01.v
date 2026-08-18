# frozen_string_literal: true

FactoryBot.define do
  factory :geo_abuse_report_upload, class: 'Geo::AbuseReportUpload' do
    # Upload partition tables are read-only. Data is written through the
    # Upload model to the uploads parent table, and PostgreSQL routes the
    # row to the correct partition by model_type.
    #
    # This factory creates a regular Upload with the appropriate model
    # association, then returns the record from the partition table.
    transient do
      parent_model { create(:abuse_report) } # rubocop:disable RSpec/FactoryBot/InlineAssociation -- See above
    end

    initialize_with do
      upload = create(:upload, :with_file, model: parent_model)
      Geo::AbuseReportUpload.find(upload.id)
    end

    trait :remote_store do
      initialize_with do
        upload = create(:upload, :object_storage, model: parent_model)
        Geo::AbuseReportUpload.find(upload.id)
      end
    end

    # Verification state is stored in a separate state table
    # (Geo::AbuseReportUploadState), not on the model itself.
    trait(:verification_succeeded) do
      after(:create) do |instance|
        state = instance.abuse_report_upload_state
        state.verification_checksum = 'abc'
        state.verification_state = Geo::AbuseReportUpload.verification_state_value(:verification_succeeded)
        state.save!
      end
    end

    trait(:verification_failed) do
      after(:create) do |instance|
        state = instance.abuse_report_upload_state
        state.verification_failure = 'Could not calculate the checksum'
        state.verification_state = Geo::AbuseReportUpload.verification_state_value(:verification_failed)
        state.save!
      end
    end

    to_create { |instance| instance } # already persisted via initialize_with
  end
end
