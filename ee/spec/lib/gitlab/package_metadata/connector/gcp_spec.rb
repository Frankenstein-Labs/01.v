# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::PackageMetadata::Connector::Gcp, feature_category: :software_composition_analysis do
  let(:sync_config) { build(:pm_sync_config, version_format: version_format, purl_type: purl_type) }
  let(:connector) { described_class.new(sync_config) }
  let(:storage) { instance_double(Google::Cloud::Storage::Project) }
  let(:bucket) { instance_double(Google::Cloud::Storage::Bucket, files: file_list) }
  let(:file_list) { instance_double(Google::Cloud::Storage::File::List, all: all_files) }
  let(:all_files) { file_names.map { |name| instance_double(Google::Cloud::Storage::File, name: name) } }
  let(:file_names) do
    [
      "#{version_format}/#{registry_id}/1675352601/000000000.#{file_suffix}",
      "#{version_format}/#{registry_id}/1675352601/000000001.#{file_suffix}",
      "#{version_format}/#{registry_id}/1675356202/000000000.#{file_suffix}",
      "#{version_format}/#{registry_id}/1675356202/000000001.#{file_suffix}",
      "#{version_format}/#{registry_id}/1675356202/000000002.#{file_suffix}",
      "#{version_format}/#{registry_id}/1675359803/000000000.#{file_suffix}"
    ]
  end

  let(:file_suffix) { sync_config.version_format == 'v1' ? 'csv' : 'ndjson' }

  before do
    allow(Google::Cloud::Storage).to receive(:anonymous).and_return(storage)
    allow(storage).to receive(:bucket).with(sync_config.base_uri, skip_lookup: true).and_return(bucket)
    allow(storage).to receive(:bucket).with(sync_config.base_uri)
      .and_return(instance_double(Google::Cloud::Storage::Bucket, labels: {}))
  end

  describe '.data_after(checkpoint)' do
    using RSpec::Parameterized::TableSyntax

    let(:checkpoint) { nil }

    subject(:data) { connector.data_after(checkpoint).to_a }

    shared_examples_for 'a gcp bucket enumerator' do
      let(:checkpoint) do
        build(:pm_checkpoint, sequence: seq, chunk: chunk, version_format: sync_config.version_format,
          purl_type: sync_config.purl_type)
      end

      context 'when no seq/chunk passed' do
        let(:seq) { nil }
        let(:chunk) { nil }
        let(:expected_files) { all_files }

        it do
          is_expected.to match([
            have_attributes(sequence: 1675352601, chunk: 0),
            have_attributes(sequence: 1675352601, chunk: 1),
            have_attributes(sequence: 1675356202, chunk: 0),
            have_attributes(sequence: 1675356202, chunk: 1),
            have_attributes(sequence: 1675356202, chunk: 2),
            have_attributes(sequence: 1675359803, chunk: 0)
          ])
        end
      end

      context 'when seq/chunk found' do
        context 'and data exists' do
          let(:seq) { 1675356202 }
          let(:chunk) { 1 }
          let(:expected_files) { all_files[4..] }

          it do
            is_expected.to match([
              have_attributes(sequence: 1675356202, chunk: 2),
              have_attributes(sequence: 1675359803, chunk: 0)
            ])
          end
        end

        context 'and no data exists' do
          let(:seq) { 1675359803 }
          let(:chunk) { 0 }
          let(:expected_files) { [] }

          it { is_expected.to match([]) }
        end
      end

      context 'when one of the parameters is not found' do
        context 'and it is seq' do
          let(:seq) { 1675356202 }
          let(:chunk) { 100 }
          let(:expected_files) { all_files }

          it do
            is_expected.to match([
              have_attributes(sequence: 1675352601, chunk: 0),
              have_attributes(sequence: 1675352601, chunk: 1),
              have_attributes(sequence: 1675356202, chunk: 0),
              have_attributes(sequence: 1675356202, chunk: 1),
              have_attributes(sequence: 1675356202, chunk: 2),
              have_attributes(sequence: 1675359803, chunk: 0)
            ])
          end
        end

        context 'and it is chunk' do
          let(:seq) { 2222222 }
          let(:chunk) { 0 }
          let(:expected_files) { all_files }

          it do
            is_expected.to match([
              have_attributes(sequence: 1675352601, chunk: 0),
              have_attributes(sequence: 1675352601, chunk: 1),
              have_attributes(sequence: 1675356202, chunk: 0),
              have_attributes(sequence: 1675356202, chunk: 1),
              have_attributes(sequence: 1675356202, chunk: 2),
              have_attributes(sequence: 1675359803, chunk: 0)
            ])
          end
        end

        context 'and both are not found' do
          let(:seq) { 123 }
          let(:chunk) { 456 }
          let(:expected_files) { all_files }

          it do
            is_expected.to match([
              have_attributes(sequence: 1675352601, chunk: 0),
              have_attributes(sequence: 1675352601, chunk: 1),
              have_attributes(sequence: 1675356202, chunk: 0),
              have_attributes(sequence: 1675356202, chunk: 1),
              have_attributes(sequence: 1675356202, chunk: 2),
              have_attributes(sequence: 1675359803, chunk: 0)
            ])
          end
        end
      end
    end

    shared_examples_for 'a lazy file downloader' do
      let(:all_files) { [gcp_file] }
      let(:gcp_file) do
        instance_double(Google::Cloud::Storage::File, name: "/1678352601/00000000.#{file_suffix}",
          download: io)
      end

      let(:io) { version_format == 'v1' ? StringIO.new("1\n2\n3") : StringIO.new("[\"1\"]\n[\"2\"]\n[\"3\"]") }

      it 'does not download the gcp file when gcp file list retrieved' do
        expect(gcp_file).not_to receive(:download)
        connector.data_after(checkpoint)
      end

      it 'downloads the gcp file only when iterating over data_file' do
        expect(gcp_file).to receive(:download)
        connector.data_after(checkpoint).each do |data_file|
          expect(data_file.to_a).to match_array([['1'], ['2'], ['3']])
        end
      end
    end

    # The license db does not use a directory structure
    # that maps 1:1 with the purl types. Therefore,
    # we test that we correctly convert between purl type
    # and registry id used by the license db structure.
    where(:purl_type, :registry_id) do
      :composer     | "packagist"
      :conan        | "conan"
      :gem          | "rubygem"
      :golang       | "go"
      :maven        | "maven"
      :npm          | "npm"
      :nuget        | "nuget"
      :pypi         | "pypi"
      :apk          | "apk"
      :rpm          | "rpm"
      :deb          | "deb"
      'cbl-mariner' | "cbl-mariner"
      :wolfi        | "wolfi"
    end

    with_them do
      context 'when version format v1' do
        let(:version_format) { 'v1' }

        it_behaves_like 'a gcp bucket enumerator'

        it_behaves_like 'a lazy file downloader'

        it { is_expected.to all(be_a(Gitlab::PackageMetadata::Connector::CsvDataFile)) }
      end

      context 'when version format v2' do
        let(:version_format) { 'v2' }

        it_behaves_like 'a gcp bucket enumerator'

        it_behaves_like 'a lazy file downloader'

        it { is_expected.to all(be_a(Gitlab::PackageMetadata::Connector::NdjsonDataFile)) }
      end
    end
  end

  describe 'bucket label fast path' do
    let(:version_format) { 'v2' }
    let(:purl_type) { :maven }
    let(:registry_id) { 'maven' }
    let(:bucket_with_metadata) do
      instance_double(Google::Cloud::Storage::Bucket, labels: bucket_labels)
    end

    let(:checkpoint) do
      build(:pm_checkpoint, sequence: seq, chunk: 0, version_format: 'v2', purl_type: :maven)
    end

    subject(:data) { connector.data_after(checkpoint).to_a }

    before do
      stub_feature_flags(package_metadata_sync_using_labels: true)
      allow(storage).to receive(:bucket).with(sync_config.base_uri).and_return(bucket_with_metadata)
    end

    context 'when instance is already synced to newest delta' do
      let(:seq) { 1675359803 }
      let(:bucket_labels) { { 'v2_maven' => '1675359803_1675356202-3_1675352601-2' } }

      it 'returns empty without calling listObjects' do
        allow(bucket).to receive(:files).and_raise('listObjects should not be called')
        expect(data).to be_empty
      end

      it 'tracks the labels_caught_up event' do
        allow(bucket).to receive(:files).and_raise('listObjects should not be called')
        expect { data }.to trigger_internal_events('sync_pmdb_v2_licenses')
          .with(additional_properties: { label: 'maven', property: 'labels_caught_up' })
      end
    end

    context 'when newer deltas exist in the label' do
      let(:seq) { 1675352601 }
      let(:bucket_labels) { { 'v2_maven' => '1675359803_1675356202-3_1675352601-2' } }

      let(:file_1675356202_0) { instance_double(Google::Cloud::Storage::File, download: StringIO.new) }
      let(:file_1675356202_1) { instance_double(Google::Cloud::Storage::File, download: StringIO.new) }
      let(:file_1675356202_2) { instance_double(Google::Cloud::Storage::File, download: StringIO.new) }
      let(:file_1675359803_0) { instance_double(Google::Cloud::Storage::File, download: StringIO.new) }

      before do
        allow(bucket).to receive(:file).with('v2/maven/1675356202/000000000.ndjson').and_return(file_1675356202_0)
        allow(bucket).to receive(:file).with('v2/maven/1675356202/000000001.ndjson').and_return(file_1675356202_1)
        allow(bucket).to receive(:file).with('v2/maven/1675356202/000000002.ndjson').and_return(file_1675356202_2)
        allow(bucket).to receive(:file).with('v2/maven/1675359803/000000000.ndjson').and_return(file_1675359803_0)
      end

      it 'fetches files directly without listObjects' do
        allow(bucket).to receive(:files).and_raise('listObjects should not be called')
        expect(data).to match([
          have_attributes(sequence: 1675356202, chunk: 0),
          have_attributes(sequence: 1675356202, chunk: 1),
          have_attributes(sequence: 1675356202, chunk: 2),
          have_attributes(sequence: 1675359803, chunk: 0)
        ])
      end

      it 'tracks the labels_hit event' do
        allow(bucket).to receive(:files).and_raise('listObjects should not be called')
        expect { data }.to trigger_internal_events('sync_pmdb_v2_licenses')
          .with(additional_properties: { label: 'maven', property: 'labels_hit' })
      end
    end

    context 'when a file listed in the label does not exist in GCS' do
      let(:seq) { 1675352601 }
      let(:bucket_labels) { { 'v2_maven' => '1675359803_1675356202-3_1675352601-2' } }

      let(:file_1675356202_0) { instance_double(Google::Cloud::Storage::File, download: StringIO.new) }
      let(:file_1675356202_2) { instance_double(Google::Cloud::Storage::File, download: StringIO.new) }
      let(:file_1675359803_0) { instance_double(Google::Cloud::Storage::File, download: StringIO.new) }

      before do
        allow(bucket).to receive(:file).with('v2/maven/1675356202/000000000.ndjson').and_return(file_1675356202_0)
        allow(bucket).to receive(:file).with('v2/maven/1675356202/000000001.ndjson').and_return(nil)
        allow(bucket).to receive(:file).with('v2/maven/1675356202/000000002.ndjson').and_return(file_1675356202_2)
        allow(bucket).to receive(:file).with('v2/maven/1675359803/000000000.ndjson').and_return(file_1675359803_0)
      end

      it 'skips the missing file and returns the rest' do
        allow(bucket).to receive(:files).and_raise('listObjects should not be called')
        expect(data).to match([
          have_attributes(sequence: 1675356202, chunk: 0),
          have_attributes(sequence: 1675356202, chunk: 2),
          have_attributes(sequence: 1675359803, chunk: 0)
        ])
      end
    end

    context 'when checkpoint is older than oldest label entry' do
      let(:seq) { 1675000000 }
      let(:bucket_labels) { { 'v2_maven' => '1675359803_1675356202-3_1675352601-2' } }

      it 'falls back to listObjects' do
        expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        data
      end

      it 'tracks the labels_fallback_stale_checkpoint event' do
        allow(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        expect { data }.to trigger_internal_events('sync_pmdb_v2_licenses')
          .with(additional_properties: { label: 'maven', property: 'labels_fallback_stale_checkpoint' })
      end
    end

    context 'when no label exists for the registry' do
      let(:seq) { 1675352601 }
      let(:bucket_labels) { {} }

      it 'falls back to listObjects' do
        expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        data
      end

      it 'tracks the labels_fallback_no_labels event' do
        allow(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        expect { data }.to trigger_internal_events('sync_pmdb_v2_licenses')
          .with(additional_properties: { label: 'maven', property: 'labels_fallback_no_labels' })
      end
    end

    context 'when label value is nil' do
      let(:seq) { 1675352601 }
      let(:bucket_labels) { { 'v2_maven' => nil } }

      it 'falls back to listObjects' do
        expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        data
      end
    end

    context 'when label value is an empty string' do
      let(:seq) { 1675352601 }
      let(:bucket_labels) { { 'v2_maven' => '' } }

      it 'falls back to listObjects' do
        expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        data
      end
    end

    context 'when label value is malformed' do
      let(:seq) { 1675352601 }

      context 'with non-numeric timestamp and chunk' do
        let(:bucket_labels) { { 'v2_maven' => 'not-a-number_xyz' } }

        it 'falls back to listObjects' do
          expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
          data
        end
      end

      context 'with valid timestamp but non-numeric chunk count' do
        let(:bucket_labels) { { 'v2_maven' => '1675359803-abc' } }

        it 'falls back to listObjects' do
          expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
          data
        end
      end
    end

    context 'when label read raises an error' do
      let(:seq) { 1675352601 }
      let(:bucket_labels) { {} }

      before do
        allow(storage).to receive(:bucket).with(sync_config.base_uri)
          .and_raise(Google::Cloud::Error, 'connection refused')
      end

      it 'tracks the exception and falls back to listObjects' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(Google::Cloud::Error))
        expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        data
      end

      it 'tracks the labels_fallback_gcs_error event' do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
        allow(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        expect { data }.to trigger_internal_events('sync_pmdb_v2_licenses')
          .with(additional_properties: { label: 'maven', property: 'labels_fallback_gcs_error' })
      end
    end

    context 'when bucket.file raises a GCP error during iteration' do
      let(:seq) { 1675352601 }
      let(:bucket_labels) { { 'v2_maven' => '1675359803_1675356202-3_1675352601-2' } }

      before do
        allow(bucket).to receive(:file).and_raise(Google::Cloud::Error, 'network error')
      end

      it 'tracks the exception and falls back to listObjects' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(Google::Cloud::Error))
        expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        data
      end

      it 'tracks the labels_fallback_gcs_error event' do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
        allow(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        expect { data }.to trigger_internal_events('sync_pmdb_v2_licenses')
          .with(additional_properties: { label: 'maven', property: 'labels_fallback_gcs_error' })
      end
    end

    context 'when checkpoint is blank (first sync)' do
      let(:checkpoint) { nil }
      let(:bucket_labels) { { 'v2_maven' => '1675359803' } }

      it 'uses listObjects for full sync' do
        expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        data
      end

      it 'tracks the listobjects_blank_checkpoint event' do
        allow(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        expect { data }.to trigger_internal_events('sync_pmdb_v2_licenses')
          .with(additional_properties: { label: 'maven', property: 'listobjects_blank_checkpoint' })
      end
    end

    # SyncService passes Checkpoint.with_path_components, which uses
    # find_or_initialize_by. On a fresh instance with no persisted row this
    # returns an unpersisted record where blank? is false but sequence is nil.
    # See issue #603943.
    context 'when checkpoint is unseeded (fresh instance, nil sequence)' do
      let(:checkpoint) do
        build(:pm_checkpoint, sequence: nil, chunk: nil, version_format: 'v2', purl_type: :maven)
      end

      let(:bucket_labels) { { 'v2_maven' => '1675359803' } }

      it 'falls back to listObjects instead of raising' do
        expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        expect { data }.not_to raise_error
      end

      it 'tracks the listobjects_blank_checkpoint event' do
        allow(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        expect { data }.to trigger_internal_events('sync_pmdb_v2_licenses')
          .with(additional_properties: { label: 'maven', property: 'listobjects_blank_checkpoint' })
      end
    end

    context 'with purl type to registry id mapping' do
      let(:sync_config) { build(:pm_sync_config, version_format: 'v2', purl_type: :golang) }
      let(:bucket_with_metadata) do
        instance_double(Google::Cloud::Storage::Bucket, labels: { 'v2_go' => '1675359803' })
      end

      let(:checkpoint) do
        build(:pm_checkpoint, sequence: 1675359803, chunk: 0, version_format: 'v2', purl_type: :golang)
      end

      it 'uses the registry_id for the label key' do
        allow(bucket).to receive(:files).and_raise('listObjects should not be called')
        expect(data).to be_empty
      end
    end

    context 'when feature flag is disabled' do
      let(:seq) { 1675352601 }
      let(:bucket_labels) { { 'v2_maven' => '1675359803_1675356202-3_1675352601-2' } }

      before do
        stub_feature_flags(package_metadata_sync_using_labels: false)
      end

      it 'falls back to listObjects regardless of labels' do
        expect(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        data
      end

      it 'does not trigger any sync-path internal event' do
        allow(bucket).to receive(:files).with(prefix: 'v2/maven/').and_return(file_list)
        expect { data }.not_to trigger_internal_events(
          'sync_pmdb_v2_advisories',
          'sync_pmdb_v2_licenses',
          'sync_pmdb_v2_cve_enrichment'
        )
      end
    end
  end

  describe 'sync-path tracking for non-labels branches' do
    let(:all_files) { [] }
    let(:checkpoint) do
      instance_double(PackageMetadata::Checkpoint, blank?: false, sequence: 1675352601)
    end

    subject(:data) { connector.data_after(checkpoint).to_a }

    # FF stubbed off to prove listobjects_v1 / listobjects_cve_enrichment /
    # listobjects_blank_checkpoint emit regardless of the labels feature flag.
    before do
      stub_feature_flags(package_metadata_sync_using_labels: false)
    end

    context 'when sync_config is v1 advisories' do
      let(:sync_config) do
        build(:pm_sync_config, data_type: 'advisories', version_format: 'v1', purl_type: :maven)
      end

      it 'tracks the listobjects_v1 event on the advisories event' do
        expect { data }.to trigger_internal_events('sync_pmdb_v2_advisories')
          .with(additional_properties: { label: 'maven', property: 'listobjects_v1' })
      end
    end

    context 'when sync_config is v1 licenses' do
      let(:sync_config) do
        build(:pm_sync_config, data_type: 'licenses', version_format: 'v1', purl_type: :npm)
      end

      it 'tracks the listobjects_v1 event on the licenses event' do
        expect { data }.to trigger_internal_events('sync_pmdb_v2_licenses')
          .with(additional_properties: { label: 'npm', property: 'listobjects_v1' })
      end
    end

    context 'when sync_config is cve_enrichment' do
      let(:sync_config) do
        PackageMetadata::SyncConfiguration.new('cve_enrichment', :gcp, 'cve-bucket', 'v2', nil)
      end

      it 'tracks the listobjects_cve_enrichment event without a label' do
        expect { data }.to trigger_internal_events('sync_pmdb_v2_cve_enrichment')
          .with(additional_properties: { property: 'listobjects_cve_enrichment' })
      end
    end

    context 'when checkpoint is blank for cve_enrichment' do
      let(:sync_config) do
        PackageMetadata::SyncConfiguration.new('cve_enrichment', :gcp, 'cve-bucket', 'v2', nil)
      end

      let(:checkpoint) { nil }

      it 'tracks the listobjects_blank_checkpoint event without a label' do
        expect { data }.to trigger_internal_events('sync_pmdb_v2_cve_enrichment')
          .with(additional_properties: { property: 'listobjects_blank_checkpoint' })
      end
    end
  end
end
