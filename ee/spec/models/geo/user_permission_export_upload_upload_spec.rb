# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::UserPermissionExportUploadUpload, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  it { expect(described_class.table_name).to eq('user_permission_export_upload_uploads') }
  it { expect(described_class.primary_key).to eq('id') }
  it { expect(described_class.superclass).to eq(::Upload) }

  describe 'Geo replication' do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:user_permission_export_upload_upload_state)
          .class_name('Geo::UserPermissionExportUploadUploadState')
          .inverse_of(:user_permission_export_upload_upload)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      # The factory creates the record via Upload, which may trigger
      # save_partition_verification_details and create the state row.
      # The shared example expects save! to create the state row
      # (count change by 1), so we delete any pre-existing state row
      # and reload the record to clear the cached association.
      let(:verifiable_model_record) do
        record = create(:geo_user_permission_export_upload_upload)
        described_class
          .verification_state_table_class.where(user_permission_export_upload_upload_id: record.id)
          .delete_all
        record.reload
      end

      let(:unverifiable_model_record) do
        record = create(:geo_user_permission_export_upload_upload, :remote_store)
        described_class
          .verification_state_table_class.where(user_permission_export_upload_upload_id: record.id)
          .delete_all
        record.reload
      end
    end

    describe 'replication/verification' do
      let_it_be(:organization_1) { create(:organization) }
      let_it_be(:organization_2) { create(:organization) }
      let_it_be(:group_1) { create(:group, organization: organization_1) }
      let_it_be(:group_2) { create(:group, organization: organization_2) }
      let_it_be(:user_1) { create(:user, organizations: [organization_1]) }
      let_it_be(:user_2) { create(:user, organizations: [organization_2]) }

      let!(:first_replicable_and_in_selective_sync) do
        parent_model = create(:user_permission_export_upload, user: user_1)
        create(:geo_user_permission_export_upload_upload, parent_model: parent_model)
      end

      let!(:second_replicable_and_in_selective_sync) do
        parent_model = create(:user_permission_export_upload, user: user_1)
        create(:geo_user_permission_export_upload_upload, parent_model: parent_model)
      end

      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        parent_model = create(:user_permission_export_upload, user: user_1)
        create(:geo_user_permission_export_upload_upload, :remote_store, parent_model: parent_model)
      end

      let!(:last_replicable_and_not_in_selective_sync) do
        parent_model = create(:user_permission_export_upload, user: user_2)
        create(:geo_user_permission_export_upload_upload, parent_model: parent_model)
      end

      before_all do
        group_1.add_developer(user_1)
        group_2.add_developer(user_2)
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
