# frozen_string_literal: true

FactoryBot.define do
  factory :geo_alert_management_metric_image_upload, class: 'Geo::AlertManagementMetricImageUpload' do
    # Upload partition tables are read-only. Data is written through the
    # Upload model to the uploads parent table, and PostgreSQL routes the
    # row to the correct partition by model_type.
    #
    # This factory creates a regular Upload with the appropriate model
    # association, then returns the record from the partition table.
    transient do
      parent_model { create(:alert_metric_image) } # rubocop:disable RSpec/FactoryBot/InlineAssociation -- See above
    end

    initialize_with do
      # AlertManagement::MetricImage's factory always attaches a file in its after(:build)
      # hook, so creating the parent_model already produces one Upload via CarrierWave.
      # Remove that auto-created Upload first so the controlled :with_file fixture used
      # by shared examples is the only one in the partition.
      Upload.where(model_type: 'AlertManagement::MetricImage', model_id: parent_model.id).delete_all
      upload = create(:upload, :with_file, model: parent_model)
      Geo::AlertManagementMetricImageUpload.find(upload.id)
    end

    trait :remote_store do
      initialize_with do
        Upload.where(model_type: 'AlertManagement::MetricImage', model_id: parent_model.id).delete_all
        upload = create(:upload, :object_storage, model: parent_model)
        Geo::AlertManagementMetricImageUpload.find(upload.id)
      end
    end

    # Verification state is stored in a separate state table
    # (Geo::AlertManagementMetricImageUploadState), not on the model itself.
    trait(:verification_succeeded) do
      after(:create) do |instance|
        state = instance.alert_management_metric_image_upload_state
        state.verification_checksum = 'abc'
        state.verification_state = Geo::AlertManagementMetricImageUpload.verification_state_value(:verification_succeeded)
        state.save!
      end
    end

    trait(:verification_failed) do
      after(:create) do |instance|
        state = instance.alert_management_metric_image_upload_state
        state.verification_failure = 'Could not calculate the checksum'
        state.verification_state = Geo::AlertManagementMetricImageUpload.verification_state_value(:verification_failed)
        state.save!
      end
    end

    to_create { |instance| instance } # already persisted via initialize_with
  end
end
