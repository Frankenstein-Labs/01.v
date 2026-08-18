# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::PackageMetadata::Connector::BaseConnector, feature_category: :software_composition_analysis do
  let(:sync_config) { build(:pm_sync_config, version_format: version_format, purl_type: purl_type) }
  let(:connector) { described_class.new(sync_config) }

  describe '.data_file_class' do
    subject(:data_file_class) { connector.send(:data_file_class) }

    let_it_be(:purl_type) { nil }

    context 'when version_format v2' do
      let(:version_format) { 'v2' }

      it { is_expected.to be(::Gitlab::PackageMetadata::Connector::NdjsonDataFile) }
    end

    context 'when version_format v1' do
      let(:version_format) { 'v1' }

      it { is_expected.to be(::Gitlab::PackageMetadata::Connector::CsvDataFile) }
    end
  end

  describe '#file_prefix' do
    subject(:file_prefix) { connector.send(:file_prefix) }

    let_it_be(:version_format) { 'v2' }

    context 'when purl_type is nil' do
      let(:purl_type) { nil }

      it 'returns just the version_format' do
        expect(file_prefix).to eq(version_format)
      end
    end

    context 'when purl_type is present' do
      let(:purl_type) { 'npm' }
      let(:registry_id) { 'npm' }

      before do
        allow(::PackageMetadata::SyncConfiguration).to receive(:registry_id).with(purl_type).and_return(registry_id)
      end

      it 'returns the joined path' do
        expect(file_prefix).to eq(File.join(version_format, registry_id))
      end
    end
  end
end
