# frozen_string_literal: true

require 'spec_helper'

# The v3 contract is exercised end to end through the malware subclass in
# malware_pds_spec.rb. This spec covers what only the shared base can show: that
# a dataset other than malware inherits the whole contract by supplying nothing
# but a token scope and a log label.
RSpec.describe Gitlab::PackageMetadata::Connector::Pds, feature_category: :software_composition_analysis do
  let(:base_uri) { 'https://pmdb-dist-svc.staging.runway.gitlab.net/v1/widgets' }
  let(:sync_config) do
    instance_double(::PackageMetadata::SyncConfiguration, base_uri: base_uri, purl_type: :npm)
  end

  let(:checkpoint) { build(:pm_checkpoint, sequence: sequence) }
  let(:sequence) { 0 }

  let(:ijwt) { 'widget-ijwt' }
  let(:cc_headers) { { 'x-gitlab-realm' => 'saas', 'x-gitlab-instance-id' => 'instance-uuid' } }
  let(:auth_headers) { cc_headers.merge('Authorization' => "Bearer #{ijwt}") }

  let(:reader) do
    instance_double(Gitlab::PackageMetadata::Connector::Archive::TarZstReader, each_entry: [entry])
  end

  let(:entry) do
    instance_double(Gitlab::PackageMetadata::Connector::Archive::TarZstReader::Entry,
      io: StringIO.new(%({"widget":1}\n)), chunk: 7)
  end

  # A second dataset, standing in for any future PDS-backed one: its own endpoint
  # comes from sync_config, and it declares only its unit primitive, archive URL
  # key and label.
  let(:widget_pds) do
    stub_const('WidgetPds', Class.new(described_class) do
      def self.unit_primitive
        :widgets
      end

      def self.archive_url_key
        'signed_url'
      end

      private

      def dataset_label
        'widgets'
      end
    end)
  end

  let(:connector) { widget_pds.new(sync_config) }

  before do
    allow(CloudConnector).to receive(:headers).with(nil).and_return(cc_headers)
    allow(Gitlab::PackageMetadata::Connector::Archive::TarZstReader).to receive(:new).and_return(reader)
  end

  def http_response(code:, body: nil)
    instance_double(HTTParty::Response, code: code, success?: code.between?(200, 299), body: body)
  end

  describe 'a dataset other than malware' do
    before do
      allow(CloudConnector::Tokens).to receive(:get)
        .with(unit_primitive: :widgets, resource: :instance).and_return(ijwt)
    end

    context 'on first sync' do
      let(:all_response) do
        { 'until' => 1_700_000_000,
          'shards' => [{ 'shard' => '00', 'signed_url' => 'https://gcs/00.tar.zst' }] }
      end

      before do
        allow(Gitlab::HTTP).to receive(:get)
          .with("#{base_uri}/all", query: { purl_type: 'npm' }, headers: auth_headers)
          .and_return(http_response(code: 200, body: all_response.to_json))
        allow(Gitlab::HTTP).to receive(:get)
          .with('https://gcs/00.tar.zst', timeout: described_class::DOWNLOAD_TIMEOUT)
          .and_return(http_response(code: 200, body: 'shard00'))
      end

      it 'reaches its own /all endpoint with a token carrying its own scope', :aggregate_failures do
        files = connector.data_after(checkpoint).to_a

        expect(CloudConnector::Tokens).to have_received(:get)
          .with(unit_primitive: :widgets, resource: :instance)
        expect(files).to contain_exactly(
          an_object_having_attributes(sequence: 1_700_000_000, chunk: 0)
        )
        expect(files).to all(be_a(Gitlab::PackageMetadata::Connector::NdjsonDataFile))
      end

      it 'logs against its own dataset label' do
        allow(Gitlab::AppJsonLogger).to receive(:info)

        expect(Gitlab::AppJsonLogger).to receive(:info)
          .with(hash_including(message: 'Fetched widgets from PDS',
            Labkit::Fields::CLASS_NAME => 'WidgetPds'))

        connector.data_after(checkpoint).to_a
      end
    end

    context 'on incremental sync' do
      let(:sequence) { 1_700_000_000 }
      let(:delta_response) do
        { 'purl_types' => { 'npm' => [{ 'delta' => '1700000600', 'signed_url' => 'https://gcs/d.tar.zst' }] } }
      end

      before do
        allow(Gitlab::HTTP).to receive(:get)
          .with("#{base_uri}/delta", query: { since: 'npm:1700000000' }, headers: auth_headers)
          .and_return(http_response(code: 200, body: delta_response.to_json))
        allow(Gitlab::HTTP).to receive(:get)
          .with('https://gcs/d.tar.zst', timeout: described_class::DOWNLOAD_TIMEOUT)
          .and_return(http_response(code: 200, body: 'delta'))
      end

      it 'reaches its own /delta endpoint with the shared cursor format' do
        expect(connector.data_after(checkpoint).to_a).to contain_exactly(
          an_object_having_attributes(sequence: 1_700_000_600, chunk: 7)
        )
      end
    end

    context 'when PDS rejects the purl_type (400)' do
      before do
        allow(Gitlab::HTTP).to receive(:get)
          .and_return(http_response(code: 400, body: '{"error":"unknown purl_type: npm"}'))
      end

      it 'inherits the per-registry skip rather than failing the run', :aggregate_failures do
        expect(Gitlab::AppJsonLogger).to receive(:warn).with(
          hash_including(message: 'Skipping purl_type: PDS rejected the request', purl_type: :npm, status: 400)
        )

        expect(connector.data_after(checkpoint).to_a).to be_empty
      end
    end

    context 'when PDS has no new data (204)' do
      before do
        allow(Gitlab::HTTP).to receive(:get).and_return(http_response(code: 204))
      end

      it 'yields nothing and logs the no-op against its own dataset label', :aggregate_failures do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(message: 'PDS reports no new widgets', status: 204,
            Labkit::Fields::CLASS_NAME => 'WidgetPds')
        )

        expect(connector.data_after(checkpoint).to_a).to be_empty
      end
    end

    context 'when PDS fails for another reason (500)' do
      before do
        allow(Gitlab::HTTP).to receive(:get).and_return(http_response(code: 500, body: 'boom'))
      end

      it 'raises so the run is retried, logging against its own dataset label', :aggregate_failures do
        expect(Gitlab::AppJsonLogger).to receive(:error).with(
          hash_including(message: 'Failed to fetch widgets from PDS', status: 500,
            Labkit::Fields::CLASS_NAME => 'WidgetPds')
        )

        expect { connector.data_after(checkpoint).to_a }
          .to raise_error(described_class::ResponseError, /500/)
      end
    end
  end

  # PDS names the archive URL `signed_url` on some endpoints and `url` on others,
  # so each dataset declares the key its own endpoints use. Every path that reads
  # an entry goes through that declaration.
  describe 'the archive URL key' do
    before do
      allow(CloudConnector::Tokens).to receive(:get)
        .with(unit_primitive: :widgets, resource: :instance).and_return(ijwt)
      allow(Gitlab::HTTP).to receive(:get)
        .with('https://gcs/00.tar.zst', timeout: described_class::DOWNLOAD_TIMEOUT)
        .and_return(http_response(code: 200, body: 'shard00'))
      allow(Gitlab::HTTP).to receive(:get)
        .with('https://gcs/d.tar.zst', timeout: described_class::DOWNLOAD_TIMEOUT)
        .and_return(http_response(code: 200, body: 'delta'))
    end

    def stub_all(shards)
      allow(Gitlab::HTTP).to receive(:get)
        .with("#{base_uri}/all", query: { purl_type: 'npm' }, headers: auth_headers)
        .and_return(http_response(code: 200,
          body: { 'until' => 1_700_000_000, 'shards' => shards }.to_json))
    end

    def stub_delta(entries)
      allow(Gitlab::HTTP).to receive(:get)
        .with("#{base_uri}/delta", query: { since: 'npm:1700000000' }, headers: auth_headers)
        .and_return(http_response(code: 200, body: { 'purl_types' => { 'npm' => entries } }.to_json))
    end

    %w[signed_url url].each do |key|
      context "when the dataset declares #{key}" do
        before do
          allow(widget_pds).to receive(:archive_url_key).and_return(key)
        end

        it 'downloads a snapshot shard' do
          stub_all([{ 'shard' => '00', key => 'https://gcs/00.tar.zst' }])

          expect(connector.data_after(checkpoint).to_a).to contain_exactly(
            an_object_having_attributes(sequence: 1_700_000_000, chunk: 0)
          )
        end

        # delta_files_for reads no checkpoint, so it needs no sequence.
        it 'downloads a bulk delta archive' do
          allow(Gitlab::HTTP).to receive(:get)
            .with("#{base_uri}/delta", hash_including(query: { since: ['npm:100'] }, headers: auth_headers))
            .and_return(http_response(code: 200, body: { 'purl_types' => {
              'npm' => [{ 'delta' => '1700000600', key => 'https://gcs/d.tar.zst' }]
            } }.to_json))

          result = connector.delta_files_for({ 'npm' => 100 })

          expect(result.transform_values { |files| files.to_a.map(&:sequence) })
            .to eq('npm' => [1_700_000_600])
        end

        context 'on incremental sync' do
          let(:sequence) { 1_700_000_000 }

          it 'downloads a delta archive' do
            stub_delta([{ 'delta' => '1700000600', key => 'https://gcs/d.tar.zst' }])

            expect(connector.data_after(checkpoint).to_a).to contain_exactly(
              an_object_having_attributes(sequence: 1_700_000_600, chunk: 7)
            )
          end
        end
      end
    end

    # No fallback to the other spelling: an entry that does not carry the declared
    # key is unusable, and saying so beats silently reading a key this dataset's
    # endpoints never send.
    context 'when a shard entry uses a key the dataset did not declare' do
      it 'is treated as malformed and skipped rather than downloaded', :aggregate_failures do
        stub_all([{ 'shard' => '00', 'url' => 'https://gcs/00.tar.zst' }])

        expect(Gitlab::AppJsonLogger).to receive(:error)
          .with(hash_including(message: 'Skipping malformed PDS shard entry'))

        expect(connector.data_after(checkpoint).to_a).to be_empty
      end
    end
  end

  describe 'the dataset hooks' do
    it 'are abstract, so the base class cannot be used directly' do
      expect { described_class.new(sync_config).data_after(checkpoint) }
        .to raise_error(Gitlab::AbstractMethodError)
    end

    it 'require the archive URL key to be declared' do
      expect { described_class.archive_url_key }.to raise_error(Gitlab::AbstractMethodError)
    end
  end
end
