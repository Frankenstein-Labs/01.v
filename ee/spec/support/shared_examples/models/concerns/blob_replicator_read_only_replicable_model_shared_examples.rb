# frozen_string_literal: true

# Include these shared examples in specs of Replicators that use
# BlobReplicatorStrategy with a read-only replicable model.
#
# Read-only replicable models (e.g. upload partition models) are models
# where records are created through a parent model (Upload), not through
# the partition model directly. This means model_record.save! does not
# trigger after_create callbacks on the partition replicator.
#
# This shared example is based on 'a blob replicator' but replaces
# tests that assume model_record.save! triggers after_create with
# direct replicator method calls.
#
# Required let variables:
#
# - model_record: A valid, persisted instance of the model class.
#
RSpec.shared_examples 'a blob replicator with a read-only replicable model' do
  include EE::GeoHelpers

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary, freeze: false) { create(:geo_node) }

  subject(:replicator) { model_record.replicator }

  before do
    stub_feature_flags(geo_project_repository_replication_v2: false)
    stub_current_geo_node(primary)
  end

  it_behaves_like 'a replicator' do
    let_it_be(:event_name) { ::Geo::ReplicatorEvents::EVENT_CREATED }
  end

  it_behaves_like 'a verifiable replicator'

  # -- Tests from 'a replicable model' adapted for read-only models --

  describe '#replicator' do
    it 'is defined and does not raise error' do
      expect(model_record.replicator).to be_a(Gitlab::Geo::Replicator)
    end
  end

  # Skip 'invokes replicator.geo_handle_after_create on create' because
  # records are created through the Upload parent model, not through the
  # partition model. Instead, test geo_handle_after_create directly.

  describe '.replicable_title' do
    it 'returns replicator title' do
      expect(described_class.replicable_title).to be_a(String)
      expect(described_class.replicable_title).not_to be_empty
    end
  end

  describe '.replicable_title_plural' do
    it 'returns replicator pluralized title' do
      expect(described_class.replicable_title_plural).to be_a(String)
      expect(described_class.replicable_title_plural).not_to be_empty
    end
  end

  describe '.replicables_for_current_secondary' do
    let_it_be(:secondary, freeze: false) { create(:geo_node) }

    before do
      stub_current_geo_node(secondary)
    end

    shared_examples 'is implemented and returns a valid relation' do
      it 'is implemented' do
        expect(model_record.class.replicables_for_current_secondary(model_record.id)).to be_an(ActiveRecord::Relation)
      end
    end

    context 'when syncing object storage is enabled' do
      before do
        secondary.update!(sync_object_storage: true)
      end

      it_behaves_like 'is implemented and returns a valid relation'
    end

    context 'when syncing object storage is disabled' do
      before do
        secondary.update!(sync_object_storage: false)
      end

      it_behaves_like 'is implemented and returns a valid relation'
    end

    context 'with selective sync disabled' do
      before do
        secondary.update!(selective_sync_type: nil)
      end

      it_behaves_like 'is implemented and returns a valid relation'
    end

    context 'with selective sync enabled for namespaces' do
      before do
        secondary.update!(selective_sync_type: 'namespaces', namespaces: [build(:group)])
      end

      it_behaves_like 'is implemented and returns a valid relation'
    end

    context 'with selective sync enabled for shards' do
      before do
        secondary.update!(selective_sync_type: 'shards', selective_sync_shards: ['broken'])
      end

      it_behaves_like 'is implemented and returns a valid relation'
    end
  end

  # -- Tests from 'a blob replicator' --

  describe '#after_verifiable_update' do
    using RSpec::Parameterized::TableSyntax

    where(:verification_enabled, :immutable, :checksum, :checksummable, :expect_verify_async) do
      true  | true  | nil      | true  | true
      true  | true  | nil      | false | false
      true  | true  | 'abc123' | true  | false
      true  | true  | 'abc123' | false | false
      true  | false | nil      | true  | true
      true  | false | nil      | false | false
      true  | false | 'abc123' | true  | true
      true  | false | 'abc123' | false | false
      false | true  | nil      | true  | false
      false | true  | nil      | false | false
      false | true  | 'abc123' | true  | false
      false | true  | 'abc123' | false | false
      false | false | nil      | true  | false
      false | false | nil      | false | false
      false | false | 'abc123' | true  | false
      false | false | 'abc123' | false | false
    end

    with_them do
      before do
        allow(described_class).to receive(:verification_enabled?).and_return(verification_enabled)
        allow(replicator).to receive_messages(
          immutable?: immutable,
          primary_checksum: checksum,
          checksummable?: checksummable
        )
      end

      it 'calls verify_async only if needed' do
        if expect_verify_async
          expect(replicator).to receive(:verify_async)
        else
          expect(replicator).not_to receive(:verify_async)
        end

        replicator.after_verifiable_update
      end
    end
  end

  describe '#geo_handle_after_create' do
    before do
      # Upload partition tables are read-only. Data is written through the
      # Upload model to the uploads parent table, and PostgreSQL routes the
      # row to the correct partition by model_type.
      #
      # The factory creates a regular Upload with the appropriate parent model
      # association, then returns the record from the partition table.
      #
      # TODO: Remover within https://gitlab.com/gitlab-org/gitlab/-/issues/589924
      model_record
    end

    context 'on a Geo primary' do
      it 'creates a Geo::Event' do
        expect do
          replicator.geo_handle_after_create
        end.to change { ::Geo::Event.count }.by(1)

        expect(::Geo::Event.last.attributes).to include(
          "replicable_name" => replicator.replicable_name,
          "event_name" => ::Geo::ReplicatorEvents::EVENT_CREATED,
          "payload" => {
            "model_record_id" => replicator.model_record.id,
            "correlation_id" => an_instance_of(String)
          }
        )
      end

      it 'calls #after_verifiable_update' do
        expect(replicator).to receive(:after_verifiable_update)

        replicator.geo_handle_after_create
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags(replicator.replication_enabled_feature_key => false)
        end

        it 'does not publish' do
          expect do
            replicator.geo_handle_after_create
          end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
        end
      end
    end

    context 'on a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does not create an event' do
        expect do
          replicator.geo_handle_after_create
        end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
      end
    end
  end

  describe '#geo_handle_after_destroy' do
    context 'on a Geo primary' do
      it 'creates a Geo::Event' do
        model_record

        expect do
          replicator.geo_handle_after_destroy
        end.to change { ::Geo::Event.count }.by(1)

        expect(::Geo::Event.last.attributes).to include(
          "replicable_name" => replicator.replicable_name,
          "event_name" => ::Geo::ReplicatorEvents::EVENT_DELETED,
          "payload" => {
            "model_record_id" => replicator.model_record.id,
            "uploader_class" => replicator.carrierwave_uploader.class.to_s,
            "blob_path" => replicator.carrierwave_uploader.relative_path.to_s
          }
        )
      end

      context 'when replication feature flag is disabled' do
        before do
          stub_feature_flags(replicator.replication_enabled_feature_key => false)
        end

        it 'does not publish' do
          expect do
            replicator.geo_handle_after_destroy
          end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
        end
      end
    end

    context 'on a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'does not create an event' do
        expect do
          replicator.geo_handle_after_destroy
        end.not_to change { ::Geo::Event.where("replicable_name" => replicator.replicable_name).count }
      end
    end
  end

  describe 'created event consumption' do
    before do
      stub_current_geo_node(secondary)
    end

    context "when the blob's project is in replicables for this geo node" do
      it 'invokes Geo::BlobDownloadService' do
        expect(replicator).to receive(:in_replicables_for_current_secondary?).and_return(true).twice
        service = instance_double(::Geo::BlobDownloadService)

        expect(service).to receive(:execute)
        expect(::Geo::BlobDownloadService).to receive(:new).with(replicator: replicator).and_return(service)

        replicator.consume(:created)
      end
    end

    context "when the blob's project is not in replicables for this geo node" do
      it 'does not invoke Geo::BlobDownloadService' do
        expect(replicator).to receive(:in_replicables_for_current_secondary?).and_return(false)

        expect(::Geo::BlobDownloadService).not_to receive(:new)

        replicator.consume(:created)
      end
    end
  end

  describe 'deleted event consumption' do
    let!(:model_record_id) { replicator.model_record_id }
    let!(:blob_path) { replicator.carrierwave_uploader.relative_path.to_s }
    let!(:uploader_class) { replicator.carrierwave_uploader.class.to_s }
    let!(:deleted_params) { { model_record_id: model_record_id, uploader_class: uploader_class, blob_path: blob_path } }
    let!(:secondary_blob_path) { File.join(uploader_class.constantize.root, blob_path) }

    before do
      stub_current_geo_node(secondary)
    end

    context 'when model_record was deleted from the DB and the replicator only has its ID' do
      before do
        model_record.delete
      end

      let(:secondary_side_replicator) { replicator.class.new(model_record_id: model_record_id) }

      it 'invokes Geo::FileRegistryRemovalService' do
        service = instance_double(::Geo::FileRegistryRemovalService, execute: true)

        expect(service).to receive(:execute)
        expect(::Geo::FileRegistryRemovalService)
          .to receive(:new)
          .with(
            secondary_side_replicator.replicable_name,
            model_record_id,
            secondary_blob_path,
            uploader_class
          )
          .and_return(service)

        secondary_side_replicator.consume(:deleted, **deleted_params)
      end
    end
  end

  describe '#carrierwave_uploader' do
    it 'is implemented' do
      expect { replicator.carrierwave_uploader }.not_to raise_error
    end
  end

  describe '#model' do
    let(:invoke_model) { replicator.class.model }

    it 'is implemented' do
      expect { invoke_model }.not_to raise_error
    end

    it 'is a Class' do
      expect(invoke_model).to be_a(Class)
    end

    it 'responds to primary_key' do
      expect(invoke_model).to respond_to(:primary_key)
    end
  end

  describe '#blob_path' do
    context 'when the file is locally stored' do
      it 'returns a valid path to a file' do
        expect(File.exist?(replicator.blob_path)).to be_truthy
      end
    end
  end

  describe '#calculate_checksum' do
    context 'when the file is verifiable' do
      context 'when the file exists' do
        context 'when the file is locally stored' do
          it 'returns hexdigest of the file' do
            expected = described_class.model.sha256_hexdigest(subject.blob_path)

            expect(subject.calculate_checksum).to eq(expected)
          end
        end
      end
    end
  end

  # rubocop:disable RSpec/VerifiedDoubles -- Uploader is different per replicable
  describe '#resource_exists?' do
    let(:file) { double(exists?: true) }
    let(:uploader) { double(file: file) }

    subject { replicator.resource_exists? }

    before do
      allow(replicator).to receive(:carrierwave_uploader).and_return(uploader)
    end

    it { is_expected.to be_truthy }

    context 'when the file does not exist' do
      let(:file) { double(exists?: false) }

      it { is_expected.to be_falsey }
    end

    context 'when the file is nil' do
      let(:file) { nil }

      it { is_expected.to be_falsey }
    end
  end
  # rubocop:enable RSpec/VerifiedDoubles
end
