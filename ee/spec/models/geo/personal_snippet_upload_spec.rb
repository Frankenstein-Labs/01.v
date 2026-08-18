# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PersonalSnippetUpload, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  it { expect(described_class.table_name).to eq('snippet_uploads') }
  it { expect(described_class.primary_key).to eq('id') }
  it { expect(described_class.superclass).to eq(::Upload) }

  describe 'Geo replication' do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:personal_snippet_upload_state)
          .class_name('Geo::PersonalSnippetUploadState')
          .inverse_of(:personal_snippet_upload)
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
        record = create(:geo_personal_snippet_upload)
        described_class.verification_state_table_class.where(personal_snippet_upload_id: record.id).delete_all
        record.reload
      end

      let(:unverifiable_model_record) do
        record = create(:geo_personal_snippet_upload, :remote_store)
        described_class.verification_state_table_class.where(personal_snippet_upload_id: record.id).delete_all
        record.reload
      end
    end

    describe 'replication/verification' do
      let_it_be(:organization_1) { create(:organization) }
      let_it_be(:organization_2) { create(:organization) }
      let_it_be(:group_1) { create(:group, organization: organization_1) }
      let_it_be(:group_2) { create(:group, organization: organization_2) }

      let!(:first_replicable_and_in_selective_sync) do
        create(:geo_personal_snippet_upload, parent_model: create(:personal_snippet, organization: organization_1))
      end

      let!(:second_replicable_and_in_selective_sync) do
        create(:geo_personal_snippet_upload, parent_model: create(:personal_snippet, organization: organization_1))
      end

      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        create(:geo_personal_snippet_upload, :remote_store,
          parent_model: create(:personal_snippet, organization: organization_1))
      end

      let!(:last_replicable_and_not_in_selective_sync) do
        create(:geo_personal_snippet_upload, parent_model: create(:personal_snippet, organization: organization_2))
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
