# frozen_string_literal: true

FactoryBot.define do
  factory :geo_organization_detail_upload, class: 'Geo::OrganizationDetailUpload' do
    # Upload partition tables are read-only. Data is written through the
    # Upload model to the uploads parent table, and PostgreSQL routes the
    # row to the correct partition by model_type.
    #
    # This factory creates a regular Upload with the appropriate model
    # association, then returns the record from the partition table.
    # Organizations::OrganizationDetail is 1:1 with Organization (organization_id
    # is its primary key), so each upload needs its own organization to avoid a
    # duplicate-key collision when several records are built. avatar: nil prevents
    # the detail from creating its own avatar upload in the partition.
    transient do
      parent_model { create(:organization_detail, organization: create(:organization), avatar: nil) } # rubocop:disable RSpec/FactoryBot/InlineAssociation -- See above
    end

    initialize_with do
      upload = create(:upload, :with_file, model: parent_model)
      Geo::OrganizationDetailUpload.find(upload.id)
    end

    trait :remote_store do
      initialize_with do
        upload = create(:upload, :object_storage, model: parent_model)
        Geo::OrganizationDetailUpload.find(upload.id)
      end
    end

    # Verification state is stored in a separate state table
    # (Geo::OrganizationDetailUploadState), not on the model itself.
    trait(:verification_succeeded) do
      after(:create) do |instance|
        state = instance.organization_detail_upload_state
        state.verification_checksum = 'abc'
        state.verification_state = Geo::OrganizationDetailUpload.verification_state_value(:verification_succeeded)
        state.save!
      end
    end

    trait(:verification_failed) do
      after(:create) do |instance|
        state = instance.organization_detail_upload_state
        state.verification_failure = 'Could not calculate the checksum'
        state.verification_state = Geo::OrganizationDetailUpload.verification_state_value(:verification_failed)
        state.save!
      end
    end

    to_create { |instance| instance } # already persisted via initialize_with
  end
end
