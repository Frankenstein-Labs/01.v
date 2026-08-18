# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::AppearanceUpload, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  it { expect(described_class.table_name).to eq('appearance_uploads') }
  it { expect(described_class.primary_key).to eq('id') }
  it { expect(described_class.superclass).to eq(::Upload) }

  describe 'Geo replication' do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:appearance_upload_state)
          .class_name('Geo::AppearanceUploadState')
          .inverse_of(:appearance_upload)
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
        record = create(:geo_appearance_upload)
        described_class.verification_state_table_class.where(appearance_upload_id: record.id).delete_all
        record.reload
      end

      let(:unverifiable_model_record) do
        record = create(:geo_appearance_upload, :remote_store)
        described_class.verification_state_table_class.where(appearance_upload_id: record.id).delete_all
        record.reload
      end
    end

    describe 'selective sync' do
      let_it_be(:secondary) { create(:geo_node, :secondary, selective_sync_type: 'namespaces') }

      before do
        stub_current_geo_node(secondary)
      end

      it 'is always replicated regardless of selective sync configuration' do
        replicable = create(:geo_appearance_upload)

        expect(described_class.selective_sync_scope(secondary)).to include(replicable)
      end
    end
  end
end
