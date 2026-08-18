# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::SyncService, feature_category: :software_composition_analysis do
  describe '#execute' do
    let(:connector) { instance_double(Gitlab::PackageMetadata::Connector::Gcp, data_after: [file1, file2]) }
    let(:file1) { Gitlab::PackageMetadata::Connector::CsvDataFile.new(StringIO.new, 1675363107, 0) }
    let(:file2) { Gitlab::PackageMetadata::Connector::CsvDataFile.new(StringIO.new, 1675366673, 0) }
    let(:should_stop) { false }
    let(:stop_signal) { double('stop signal', stop?: should_stop) } # rubocop:disable RSpec/VerifiedDoubles
    let(:data_objects) { build_list(:pm_data_object, 3, purl_type: sync_config.purl_type) }

    let(:service) { described_class.new(sync_config, stop_signal) }
    let(:sync_config) { build(:pm_sync_config, version_format: 'v1') }

    subject(:execute) { service.execute }

    before do
      allow(PackageMetadata::DataObjectFabricator).to receive(:new)
        .with(data_file: file1, sync_config: sync_config).and_return(data_objects)
      allow(PackageMetadata::DataObjectFabricator).to receive(:new)
        .with(data_file: file2, sync_config: sync_config).and_return(data_objects)
      allow(Gitlab::PackageMetadata::Connector::Gcp).to receive(:new).and_return(connector)
      allow(Gitlab::PackageMetadata::Connector::Offline).to receive(:new).and_return(connector)
      allow(PackageMetadata::Ingestion::IngestionService).to receive(:execute)
      allow(PackageMetadata::Ingestion::CompressedPackage::IngestionService).to receive(:execute)
      allow(PackageMetadata::Ingestion::Advisory::IngestionService).to receive(:execute)
      allow(PackageMetadata::Ingestion::CveEnrichment::IngestionService).to receive(:execute)
      allow(service).to receive(:sleep)
      allow(Gitlab::AppJsonLogger).to receive(:debug)
    end

    shared_examples_for 'it syncs imported data' do
      let(:checkpoint) do
        PackageMetadata::Checkpoint.first_or_initialize(purl_type: sync_config.purl_type,
          version_format: sync_config.version_format, data_type: sync_config.data_type)
      end

      it 'calls connector with the correct checkpoint' do
        execute
        expect(connector).to have_received(:data_after).with(checkpoint)
      end

      context 'when ingesting' do
        context 'if version_format is v2' do
          before do
            sync_config.version_format = 'v2'
          end

          it 'calls compressed package ingestion service to store data' do
            execute
            expect(PackageMetadata::Ingestion::CompressedPackage::IngestionService)
              .to have_received(:execute).with(data_objects).twice
          end
        end

        context 'if version_format is v1' do
          before do
            sync_config.version_format = 'v1'
          end

          it 'calls v1 ingestion service to store data' do
            execute
            expect(PackageMetadata::Ingestion::IngestionService)
              .to have_received(:execute).with(data_objects).twice
          end
        end

        context 'if data_type is advisories' do
          before do
            sync_config.data_type = 'advisories'
          end

          it 'calls advisories ingestion service to store data' do
            execute
            expect(PackageMetadata::Ingestion::Advisory::IngestionService)
              .to have_received(:execute).with(data_objects).twice
          end
        end

        context 'if data_type is cve enrichment' do
          let(:checkpoint) do
            create(:pm_checkpoint, purl_type: sync_config.purl_type, data_type: sync_config.data_type)
          end

          before do
            sync_config.data_type = 'cve_enrichment'
          end

          it 'always calls data_after(NullCheckpoint) even if checkpoints exist' do
            checkpoint
            execute
            expect(connector).to have_received(:data_after).with(an_instance_of(PackageMetadata::NullCheckpoint))
          end

          it 'does not update the checkpoint' do
            expect { execute }.not_to change { checkpoint.reload.attributes }
          end

          it 'calls cve enrichment ingestion service to store data' do
            execute
            expect(PackageMetadata::Ingestion::CveEnrichment::IngestionService)
              .to have_received(:execute).with(data_objects).twice
          end
        end
      end

      context 'when a slice has been ingested' do
        context 'and it is in dev mode' do
          before do
            stub_env('PM_SYNC_IN_DEV', 'true')
          end

          it 'throttles calls to ingestion service after each ingested slice' do
            expect(service).not_to receive(:sleep)
            service.execute
          end
        end

        context 'and it is not in dev mode' do
          it 'throttles calls to ingestion service after each ingested slice' do
            expect(service).to receive(:sleep).with(described_class::THROTTLE_RATE).twice
            service.execute
          end
        end
      end

      it 'logs progress with correct sync position' do
        service.execute
        expect(Gitlab::AppJsonLogger).to have_received(:debug)
          .with(hash_including(message: "Evaluating data for #{sync_config}/#{file1}")).once
        expect(Gitlab::AppJsonLogger).to have_received(:debug)
          .with(hash_including(message: "Evaluating data for #{sync_config}/#{file2}")).once
      end
    end

    context 'when checkpoint exists' do
      let(:checkpoint) do
        create(:pm_checkpoint, purl_type: sync_config.purl_type, version_format: sync_config.version_format,
          data_type: sync_config.data_type)
      end

      it_behaves_like 'it syncs imported data'

      it 'updates the checkpoint to the last returned file' do
        expect { execute }.to change { [checkpoint.reload.sequence, checkpoint.reload.chunk] }
          .from([checkpoint.sequence, checkpoint.chunk]).to([file2.sequence, file2.chunk])
      end
    end

    context 'when checkpoint does not exist' do
      it_behaves_like 'it syncs imported data'

      it 'stores the last returned file in a new checkpoint' do
        expect { execute }.to change { PackageMetadata::Checkpoint.count }
          .from(0).to(1)

        checkpoint = PackageMetadata::Checkpoint.where(purl_type: sync_config.purl_type,
          version_format: sync_config.version_format, data_type: sync_config.data_type)
          .first
        expect(checkpoint.sequence).to eq(file2.sequence)
        expect(checkpoint.chunk).to eq(file2.chunk)
      end
    end

    context 'when an error occurs during execution' do
      let(:seq) { 0 }
      let(:chunk) { 0 }
      let!(:checkpoint) do
        create(:pm_checkpoint, purl_type: sync_config.purl_type, sequence: seq, chunk: chunk)
      end

      before do
        allow(service).to receive(:ingest).and_raise(StandardError)
      end

      it 'does not update the checkpoint so as not to skip the errored file' do
        expect { execute }.to raise_error(StandardError)
        expect([checkpoint.reload.sequence, checkpoint.reload.chunk]).to match_array([seq, chunk])
      end
    end

    context 'when signal_stop.stop? is true' do
      let(:should_stop) { true }

      it 'terminates after checkpointing' do
        execute
        checkpoint = PackageMetadata::Checkpoint.where(purl_type: sync_config.purl_type,
          version_format: sync_config.version_format, data_type: sync_config.data_type).first
        expect(checkpoint.sequence).to eq(file1.sequence)
        expect(checkpoint.chunk).to eq(file1.chunk)
        expect(PackageMetadata::Ingestion::IngestionService)
          .to have_received(:execute).with(data_objects).once
      end
    end

    context 'when storage_type is gcp' do
      let(:sync_config) { build(:pm_sync_config, storage_type: :gcp) }

      it_behaves_like 'it syncs imported data'
    end

    context 'when storage_type is offline' do
      let(:sync_config) { build(:pm_sync_config, storage_type: :offline) }

      it_behaves_like 'it syncs imported data'
    end

    context 'when syncing malware advisories (resumable full sync)' do
      let(:sync_config) do
        build(:pm_sync_config, data_type: 'malware_advisories', storage_type: :pds,
          base_uri: 'https://pmdb', version_format: 'v3', purl_type: :npm)
      end

      let(:checkpoint) do
        PackageMetadata::Checkpoint.with_path_components('malware_advisories', 'v3', :npm)
      end

      let(:until_seq) { 1_783_077_798 }
      let(:shard0) { Gitlab::PackageMetadata::Connector::NdjsonDataFile.new(StringIO.new, until_seq, 0) }
      let(:shard1) { Gitlab::PackageMetadata::Connector::NdjsonDataFile.new(StringIO.new, until_seq, 1) }
      let(:connector) do
        instance_double(Gitlab::PackageMetadata::Connector::MalwarePds, data_after: [shard0, shard1])
      end

      before do
        allow(Gitlab::PackageMetadata::Connector::MalwarePds).to receive(:new).and_return(connector)
        allow(PackageMetadata::DataObjectFabricator).to receive(:new)
          .with(data_file: shard0, sync_config: sync_config).and_return(data_objects)
        allow(PackageMetadata::DataObjectFabricator).to receive(:new)
          .with(data_file: shard1, sync_config: sync_config).and_return(data_objects)
      end

      context 'on a fresh first sync that completes' do
        it 'pins full_sync_target_sequence on the first shard, then clears it once the dataset is ingested',
          :aggregate_failures do
          execute

          expect(checkpoint.sequence).to eq(until_seq)
          expect(checkpoint.chunk).to eq(1)
          expect(checkpoint.full_sync_target_sequence).to be_nil
        end
      end

      context 'when interrupted mid dataset' do
        let(:should_stop) { true }

        it 'retains the marker so the next run still routes to /all and resumes', :aggregate_failures do
          execute

          expect(checkpoint.sequence).to eq(until_seq)
          expect(checkpoint.chunk).to eq(0)
          expect(checkpoint.full_sync_target_sequence).to eq(until_seq)
          expect(checkpoint.first_sync?).to be(true)
        end
      end

      context 'when resuming a sync that already has the marker set' do
        before do
          create(:pm_checkpoint, data_type: 'malware_advisories', version_format: 'v3',
            purl_type: :npm, sequence: until_seq, chunk: 0, full_sync_target_sequence: until_seq)
        end

        it 'ingests the remaining shards and clears the marker on completion', :aggregate_failures do
          execute

          expect(checkpoint.chunk).to eq(1)
          expect(checkpoint.full_sync_target_sequence).to be_nil
        end
      end
    end

    context 'when storage_type is unknown' do
      let(:sync_config) { build(:pm_sync_config, storage_type: :foo) }

      it 'raises an error' do
        expect { execute }.to raise_error(described_class::UnknownAdapterError)
      end
    end
  end

  describe '.execute' do
    let(:observer) { instance_double(described_class) }
    let(:lease) { instance_double(Gitlab::ExclusiveLease) }
    let(:stop_signal) { instance_double(PackageMetadata::StopSignal, stop?: should_stop) }
    let(:enabled_purl_types) { ApplicationSetting.create_from_defaults.package_metadata_purl_types_names }

    subject(:execute) { described_class.execute(data_type: data_type, lease: lease) }

    before do
      allow(PackageMetadata::StopSignal).to receive(:new)
        .with(lease, described_class::MAX_LEASE_LENGTH, described_class::MAX_SYNC_DURATION)
        .and_return(stop_signal)
    end

    shared_examples_for 'it calls #execute for each enabled config' do
      let(:should_stop) { false }

      specify do
        expect(observer).to receive(:execute).exactly(enabled_purl_types.size).times
        enabled_purl_types.each do |purl_type, _|
          expect(described_class).to receive(:new)
            .with(having_attributes(data_type: data_type, purl_type: purl_type), stop_signal)
            .and_return(observer)
        end
        execute
      end
    end

    context 'when stop_signal.stop? is false' do
      context 'and the data_type is licenses' do
        let(:data_type) { 'licenses' }

        it_behaves_like 'it calls #execute for each enabled config'
      end

      context 'and the data_type is advisories' do
        let(:data_type) { 'advisories' }

        it_behaves_like 'it calls #execute for each enabled config'
      end

      context 'and the data_type is cve_enrichment' do
        let(:data_type) { 'cve_enrichment' }
        let(:should_stop) { false }

        it 'calls #execute once' do
          expect(observer).to receive(:execute).once
          expect(described_class).to receive(:new)
            .with(having_attributes(data_type: data_type, purl_type: nil), stop_signal)
            .and_return(observer)
          execute
        end
      end
    end

    context 'when stop_signal.stop? is true' do
      let(:should_stop) { true }
      let(:data_type) { 'licenses' }

      it 'does not proceed' do
        expect(described_class).not_to receive(:new)
        execute
      end
    end
  end

  describe 'connector selection' do
    let(:signal) { instance_double(PackageMetadata::StopSignal) }

    # Drive the public #execute path and assert which connector it builds,
    # rather than reaching into the private #connector method.
    def expect_sync_via(connector_class)
      connector = instance_double(connector_class, data_after: [])
      expect(connector_class).to receive(:new).with(sync_config).and_return(connector)

      described_class.new(sync_config, signal).execute
    end

    context 'when storage_type is pds' do
      let(:sync_config) { build(:pm_sync_config, storage_type: :pds, data_type: 'malware_advisories') }

      it 'syncs through the PDS connector' do
        expect_sync_via(Gitlab::PackageMetadata::Connector::MalwarePds)
      end
    end

    context 'when storage_type is offline for malware advisories' do
      let(:sync_config) { build(:pm_sync_config, storage_type: :offline, data_type: 'malware_advisories') }

      it 'syncs through the malware offline connector' do
        expect_sync_via(Gitlab::PackageMetadata::Connector::MalwareOffline)
      end
    end

    context 'when storage_type is offline for another data type' do
      let(:sync_config) { build(:pm_sync_config, storage_type: :offline, data_type: 'advisories') }

      it 'syncs through the offline connector' do
        expect_sync_via(Gitlab::PackageMetadata::Connector::Offline)
      end
    end
  end
end
