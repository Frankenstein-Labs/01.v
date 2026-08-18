# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Tools::Resolutions::Resync, :geo, feature_category: :geo_replication do
  let(:error_type) { Geo::Errors::ErrorType.find_by(name: 'url_blocked') }

  subject(:resolution) { described_class.new(error_type) }

  describe '#affected_count' do
    it 'counts failed registries whose failure matches the pattern' do
      create(:geo_package_file_registry, :failed, last_sync_failure: 'URL is blocked: host')
      create(:geo_package_file_registry, :failed, last_sync_failure: 'some other failure')
      create(:geo_package_file_registry, :synced)

      expect(resolution.affected_count).to eq(1)
    end

    it 'counts matches spread across batches' do
      stub_const("#{described_class.superclass}::BATCH_SIZE", 1)
      create_list(:geo_package_file_registry, 2, :failed, last_sync_failure: 'URL is blocked: host')
      create(:geo_package_file_registry, :failed, last_sync_failure: 'some other failure')

      expect(resolution.affected_count).to eq(2)
    end
  end

  describe '#sample' do
    it 'describes the matching registries' do
      registry = create(:geo_package_file_registry, :failed, last_sync_failure: 'URL is blocked: host')

      expect(resolution.sample).to include(a_string_starting_with("Geo::PackageFileRegistry ##{registry.id}"))
    end
  end

  describe '#apply' do
    it 'resyncs the matching registries through the bulk service', :aggregate_failures do
      registry = create(:geo_package_file_registry, :failed, last_sync_failure: 'URL is blocked: host')
      service = instance_double(Geo::BulkRegistryResyncService, async_execute: nil)

      expect(Geo::BulkRegistryResyncService)
        .to receive(:new)
        .with('Geo::PackageFileRegistry', ids: a_collection_including(registry.id))
        .and_return(service)

      expect(resolution.apply).to eq(1)
    end

    it 'resyncs at most the limit', :aggregate_failures do
      create_list(:geo_package_file_registry, 3, :failed, last_sync_failure: 'URL is blocked: host')
      service = instance_double(Geo::BulkRegistryResyncService, async_execute: nil)

      expect(Geo::BulkRegistryResyncService).to receive(:new) do |class_name, ids:|
        expect(class_name).to eq('Geo::PackageFileRegistry')
        expect(ids.size).to eq(2)
        service
      end

      expect(resolution.apply(limit: 2)).to eq(2)
    end
  end

  context 'when the error type has no match pattern' do
    let(:error_type) { instance_double(Geo::Errors::ErrorType, match_pattern: nil) }

    it 'acts on nothing', :aggregate_failures do
      create(:geo_package_file_registry, :failed, last_sync_failure: 'URL is blocked: host')

      expect(Geo::BulkRegistryResyncService).not_to receive(:new)
      expect(resolution.affected_count).to eq(0)
      expect(resolution.apply).to eq(0)
    end
  end
end
