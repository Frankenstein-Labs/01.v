# frozen_string_literal: true

FactoryBot.define do
  factory :geo_project_import_export_relation_export_upload_upload,
    class: 'Geo::ProjectImportExportRelationExportUploadUpload' do
    # Upload partition tables are read-only. Data is written through the
    # Upload model to the uploads parent table, and PostgreSQL routes the
    # row to the correct partition by model_type.
    #
    # The parent model's CarrierWave mount_uploader on export_file creates
    # an Upload row when the parent saves. We pass an empty tar.gz so the
    # created Upload has a zero-byte file, matching the empty-file checksum
    # fixture used by the shared replicator examples.
    transient do
      parent_model do
        empty_export_file = Tempfile.new(%w[empty .tar.gz]).tap(&:close)
        # strategy: :create forces persistence even when the outer factory uses :build
        # (e.g. build(:geo_..._registry)), so CarrierWave fires and creates the backing Upload row.
        association(:project_import_export_relation_export_upload, strategy: :create,
          export_file: Rack::Test::UploadedFile.new(empty_export_file.path, 'application/gzip'))
      end
    end

    initialize_with do
      upload = ::Upload.where(
        model_type: 'Projects::ImportExport::RelationExportUpload',
        model_id: parent_model.id
      ).last
      Geo::ProjectImportExportRelationExportUploadUpload.find(upload.id)
    end

    trait :remote_store do
      initialize_with do
        upload = ::Upload.where(
          model_type: 'Projects::ImportExport::RelationExportUpload',
          model_id: parent_model.id
        ).last
        upload.update!(store: ObjectStorage::Store::REMOTE)
        Geo::ProjectImportExportRelationExportUploadUpload.find(upload.id)
      end
    end

    # Verification state is stored in a separate state table
    # (Geo::ProjectImportExportRelationExportUploadUploadState), not on the model itself.
    trait(:verification_succeeded) do
      after(:create) do |instance|
        state = instance.project_import_export_relation_export_upload_upload_state
        state.verification_checksum = 'abc'
        state.verification_state =
          Geo::ProjectImportExportRelationExportUploadUpload.verification_state_value(:verification_succeeded)
        state.save!
      end
    end

    trait(:verification_failed) do
      after(:create) do |instance|
        state = instance.project_import_export_relation_export_upload_upload_state
        state.verification_failure = 'Could not calculate the checksum'
        state.verification_state =
          Geo::ProjectImportExportRelationExportUploadUpload.verification_state_value(:verification_failed)
        state.save!
      end
    end

    to_create { |instance| instance } # already persisted via initialize_with
  end
end
