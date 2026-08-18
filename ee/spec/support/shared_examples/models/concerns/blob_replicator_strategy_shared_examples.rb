# frozen_string_literal: true

# Include these shared examples in specs of Replicators that include
# BlobReplicatorStrategy.
#
# Required let variables:
#
# - model_record: A valid, unpersisted instance of the model class. Or a valid,
#                 persisted instance of the model class in a not-yet loaded let
#                 variable (so we can trigger creation).
#
RSpec.shared_examples 'a blob replicator' do
  include EE::GeoHelpers

  let_it_be(:primary, freeze: false) { create(:geo_node, :primary) }
  let_it_be(:secondary, freeze: false) { create(:geo_node) }

  subject(:replicator) { model_record.replicator }

  before do
    # These tests create projects and expect the Geo::Event counts to change
    # including project creation related events.
    # Disabling this flag will allow project repository replication V1 to
    # work, as these tests expect.
    stub_feature_flags(geo_project_repository_replication_v2: false)
    stub_current_geo_node(primary)
  end

  it_behaves_like 'a replicator' do
    let_it_be(:event_name, freeze: false) { ::Geo::ReplicatorEvents::EVENT_CREATED }
  end

  it_behaves_like 'a verifiable replicator'

  # This could be included in each model's spec, but including it here is DRYer.
  include_examples 'a replicable model' do
    let(:replicator_class) { described_class }
  end

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
        allow(replicator).to receive(:immutable?).and_return(immutable)
        allow(replicator).to receive(:primary_checksum).and_return(checksum)
        allow(replicator).to receive(:checksummable?).and_return(checksummable)
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
    context 'on a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'creates a Geo::Event' do
        model_record.save!

        expect do
          replicator.geo_handle_after_create
        end.to change { ::Geo::Event.count }.by(1)

        expect(::Geo::Event.last.attributes).to include(
          "replicable_name" => replicator.replicable_name,
          "event_name" => ::Geo::ReplicatorEvents::EVENT_CREATED,
          # Match the payload exactly against the replicator's own event_params (correlation_id is
          # dynamic) so unexpected keys are caught, while partitioned replicators that legitimately
          # add a partition key still pass.
          "payload" => match(replicator.event_params.merge("correlation_id" => an_instance_of(String)))
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
      before do
        stub_current_geo_node(primary)
      end

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
    before do
      model_record.save!
      stub_current_geo_node(secondary)
    end

    let!(:model_record_id) { replicator.model_record_id }
    let!(:blob_path) { replicator.carrierwave_uploader.relative_path.to_s }
    let!(:uploader_class) { replicator.carrierwave_uploader.class.to_s }
    let!(:deleted_params) { { model_record_id: model_record_id, uploader_class: uploader_class, blob_path: blob_path } }
    let!(:secondary_blob_path) { File.join(uploader_class.constantize.root, blob_path) }

    context 'when model_record was deleted from the DB and the replicator only has its ID' do
      before do
        model_record.delete
      end

      # The replicator is instantiated by Geo::EventService on the secondary
      # side, after the model_record no longer exists. This line ensures the
      # replicator does not hold an instance of ActiveRecord::Base, which helps
      # avoid a regression of
      # https://gitlab.com/gitlab-org/gitlab/-/issues/233040
      let(:secondary_side_replicator) { replicator.class.new(model_record_id: model_record_id) }

      it 'invokes Geo::FileRegistryRemovalService' do
        service = double(:service)

        expect(service).to receive(:execute)
        expect(::Geo::FileRegistryRemovalService)
          .to receive(:new).with(secondary_side_replicator.replicable_name, model_record_id, secondary_blob_path, uploader_class).and_return(service)

        secondary_side_replicator.consume(:deleted, **deleted_params)
      end

      context 'backward compatibility' do
        let!(:deprecated_deleted_params) { { model_record_id: model_record_id, blob_path: blob_path } }

        it 'invokes Geo::FileRegistryRemovalService when delete event is in deprecated format' do
          service = double(:service)

          expect(service).to receive(:execute)
          expect(::Geo::FileRegistryRemovalService)
            .to receive(:new).with(secondary_side_replicator.replicable_name, model_record_id, blob_path, nil).and_return(service)

          secondary_side_replicator.consume(:deleted, **deprecated_deleted_params)
        end
      end

      context 'when object storage is enabled' do
        let(:config) { uploader_class.constantize.options.object_store }
        let(:connection) { Fog::Storage.new(config.connection.to_hash.deep_symbolize_keys) }
        let(:directory) { connection.directories.new(key: config.remote_directory) }

        before do
          stub_object_storage_uploader(config: config, uploader: uploader_class.constantize)
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(secondary_blob_path).and_return(false)
          directory.files.create(key: blob_path) # rubocop:disable Rails/SaveBang
        end

        context 'when GitLab managed replication is enabled' do
          it 'deletes the file from object storage' do
            service = ::Geo::FileRegistryRemovalService.new(secondary_side_replicator.replicable_name, model_record_id, secondary_blob_path, uploader_class)
            expect(directory.files.head(blob_path)).not_to be_nil
            service.execute
            expect(directory.files.head(blob_path)).to be_nil
          end
        end

        context 'when GitLab managed replication is disabled' do
          before do
            allow(secondary).to receive(:sync_object_storage).and_return(false)
          end

          it 'does not delete the file from object storage' do
            service = ::Geo::FileRegistryRemovalService.new(secondary_side_replicator.replicable_name, model_record_id, secondary_blob_path, uploader_class)
            expect(directory.files.head(blob_path)).not_to be_nil
            service.execute
            expect(directory.files.head(blob_path)).not_to be_nil
          end
        end
      end
    end
  end

  describe '#consume_event_created' do
    before do
      stub_current_geo_node(secondary)
    end

    context 'when not in replicables for current secondary' do
      before do
        allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(false)
      end

      it 'does not download' do
        expect(replicator).not_to receive(:download)

        replicator.consume_event_created
      end
    end

    context 'when in replicables for current secondary' do
      before do
        allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(true)
        allow(replicator).to receive(:download)
      end

      context 'with a persisted registry' do
        let(:registry) { instance_double(described_class.registry_class, persisted?: true) }

        before do
          allow(replicator).to receive(:registry).and_return(registry)
          allow(registry).to receive(:pending!)
        end

        context 'when mutable' do
          before do
            allow(replicator).to receive(:mutable?).and_return(true)
          end

          it 'marks registry as pending' do
            replicator.consume_event_created

            expect(registry).to have_received(:pending!)
          end
        end

        context 'when immutable' do
          before do
            allow(replicator).to receive(:mutable?).and_return(false)
          end

          it 'does not call registry.pending!' do
            replicator.consume_event_created

            expect(registry).not_to have_received(:pending!)
          end
        end
      end

      context 'when registry is not persisted' do
        it 'does not call registry.pending!' do
          expect(replicator.registry.persisted?).to be(false)
          expect(replicator.registry).not_to receive(:pending!)

          replicator.consume_event_created
        end
      end
    end
  end

  describe '#sync' do
    context 'when not in replicables for current secondary' do
      before do
        stub_current_geo_node(secondary)
        allow(replicator).to receive(:in_replicables_for_current_secondary?).and_return(false)
      end

      it 'does not download' do
        expect(Geo::BlobDownloadService).not_to receive(:new)

        replicator.sync
      end
    end
  end

  describe '.sync_timeout' do
    it 'returns the blob_download_timeout from current node as a duration' do
      stub_current_geo_node(secondary)

      expect(described_class.sync_timeout).to eq(secondary.blob_download_timeout.seconds)
    end
  end

  describe 'oldest_unsynced' do
    before do
      stub_current_geo_node(secondary)
    end

    context 'when there are no unsynced objects' do
      it 'returns -1' do
        expect(described_class.oldest_unsynced).to eq(-1)
      end
    end

    context 'when there are unsynced objects' do
      let_it_be(:model_class_factory, freeze: false) { registry_factory_name(described_class.registry_class) }
      let_it_be(:replicable, freeze: false) { create(model_class_factory, :started) }

      it 'returns the last update time of the oldest unsynced object' do
        expect(described_class.oldest_unsynced).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe '#carrierwave_uploader' do
    it 'is implemented' do
      expect do
        replicator.carrierwave_uploader
      end.not_to raise_error
    end
  end

  describe '#model' do
    let(:invoke_model) { replicator.class.model }

    it 'is implemented' do
      expect do
        invoke_model
      end.not_to raise_error
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
        file_exist = File.exist?(replicator.blob_path)

        expect(file_exist).to be_truthy
      end
    end
  end

  describe '#calculate_checksum' do
    before do
      model_record.save! unless model_record.persisted?
    end

    context 'when the file is verifiable' do
      context 'when the file exists' do
        context 'when the file is locally stored' do
          # Avoid stubbing conditionals on this test. It helps to truly exercise the
          # method for *all* replicator classes. If one replicator class fails, then
          # setup isn't quite right for that one replicator, and we need to adjust
          # setup to know that calculate checksum works for that replicator.
          it 'returns hexdigest of the file' do
            expected = described_class.model.sha256_hexdigest(subject.blob_path)

            expect(subject.calculate_checksum).to eq(expected)
          end
        end

        context 'when the file is remotely stored' do
          it 'returns the the size of the file' do
            carrierwave_uploader = replicator.carrierwave_uploader
            allow(carrierwave_uploader).to receive(:file_storage?).and_return(false)
            allow(carrierwave_uploader).to receive_message_chain(:file, size: 65112)
            allow(carrierwave_uploader).to receive_message_chain(:file, exists?: true)
            allow(replicator).to receive(:carrierwave_uploader).and_return(carrierwave_uploader)

            # Padding file size string with a leading zero because it should be of even length
            expect(subject.calculate_checksum).to eq('065112')
          end
        end
      end

      context 'when the file does not exist' do
        it 'raises an error with file path details' do
          allow(model_record).to receive(:in_verifiables?).and_return(true)
          allow(subject).to receive(:resource_exists?).and_return(false)
          allow(subject).to receive(:blob_path).and_return('/path/to/missing/file.txt')

          expect { subject.calculate_checksum }.to raise_error(
            Geo::Errors::ReplicableDoesNotExistError,
            "File is not checksummable - file does not exist at: /path/to/missing/file.txt"
          )
        end
      end
    end

    context 'when the file is not verifiable' do
      it 'raises an error with verifiables scope details' do
        allow(subject).to receive(:resource_exists?).and_return(true)
        allow(model_record).to receive(:in_verifiables?).and_return(false)

        expect { subject.calculate_checksum }.to raise_error("File is not checksummable - #{model_record.class.name} #{model_record.id} is excluded from verification")
      end
    end

    context 'when checksummable? is true' do
      it 'does not call not_checksummable_error and completes successfully' do
        allow(model_record).to receive(:in_verifiables?).and_return(true)
        allow(subject).to receive(:resource_exists?).and_return(true)
        allow(subject.carrierwave_uploader).to receive(:file_storage?).and_return(true)
        allow(described_class.model).to receive(:sha256_hexdigest).and_return('abc123')

        expect(subject).not_to receive(:not_checksummable_error)
        expect(subject.calculate_checksum).to eq('abc123')
      end
    end
  end

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

    context 'when object storage returns 403 Forbidden (missing ListBucket permission)' do
      before do
        allow(file).to receive(:exists?).and_raise(Excon::Error::Forbidden, 'Expected(200) <=> Actual(403 Forbidden)')
      end

      it { is_expected.to be_falsey }

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(Excon::Error::Forbidden),
          hash_including(replicable_name: replicator.replicable_name, model_record_id: replicator.model_record_id)
        )

        subject
      end

      it 'logs a warning' do
        message = 'Received Forbidden error when checking if resource exists in object storage. ' \
          'Ensure the IAM role has the ListBucket permission. Treating as not found.'

        expect(Gitlab::Geo::Logger).to receive(:warn)
                                         .with(hash_including(message: message,
                                           replicable_name: replicator.replicable_name,
                                           model_record_id: replicator.model_record_id))

        subject
      end
    end
  end

  describe '.bulk_create_delete_events_async' do
    let(:uploads) { create_list(:upload, 2) }
    let(:upload_deleted_details) { uploads.map { |upload| upload.replicator.deleted_params } }
    let(:inherited_replicator_class) { described_class }

    it 'creates events' do
      expect { inherited_replicator_class.bulk_create_delete_events_async(upload_deleted_details) }
        .to change { ::Geo::Event.count }.from(0).to(4)

      expect(::Geo::EventLog.last.event).to be_present
    end

    it 'passes a valid JSON parameter to BatchEventCreateWorker' do
      expect(Geo::BatchEventCreateWorker).to receive(:perform_async).with(param_containing_valid_native_json_types)

      inherited_replicator_class.bulk_create_delete_events_async(upload_deleted_details)
    end

    it 'raises error when model_record_id is nil' do
      expect do
        inherited_replicator_class.bulk_create_delete_events_async([{}])
      end.to raise_error(RuntimeError, /model_record_id can not be nil/)
    end
  end
end
